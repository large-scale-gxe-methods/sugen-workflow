task process_phenos {
	
	File phenofile
	File? idfile
	String sample_id_header
	String outcome
	String exposure
	String covar_names
	String? delimiter
	String? missing
	Int ppmem

	command {
		python3 /format_sugen_phenos.py ${phenofile} ${sample_id_header} ${outcome} ${exposure} "${covar_names}" "${delimiter}" ${missing} "${idfile}"
	}

	runtime {
		docker: "quay.io/large-scale-gxe-methods/sugen-workflow"
		memory: ppmem + "GB"
	}

        output {
                File pheno_fmt = "sugen_phenotypes.tsv"
	}
}

task run_interaction {
  
        File genofile
        File phenofile
	String sample_id_header
	String outcome
	Boolean binary_outcome
	String exposure
	String covar_names
	Boolean robust
	Int memory
	Int disk
	Int monitoring_freq

	String mode = if binary_outcome then "palogist" else "palinear"
	String cov_formula = if covar_names == "" then "" else "+" + sub(covar_names, " ", "+")
	String formula = outcome + "=" + exposure + cov_formula

        command {	
		tabix -p vcf -f ${genofile}

		dstat -c -d -m --nocolor ${monitoring_freq} > system_resource_usage.log &
		atop -x -P PRM ${monitoring_freq} | grep '(SUGEN)' > process_resource_usage.log &

		$SUGEN \
			--pheno ${phenofile} \
			--formula ${formula} \
			--id-col ${sample_id_header} \
			--family-col ${sample_id_header} \
			--vcf ${genofile} \
			--dosage \
			--unweighted \
			--model ${true="logistic" false="linear" binary_outcome} \
			${true="--robust-variance" false="" robust} \
			--ge ${exposure} \
			--out-prefix sugen_res
        }

	runtime {
		docker: "quay.io/large-scale-gxe-methods/sugen-workflow"
		memory: "${memory} GB"
		disks: "local-disk ${disk} HDD"
		gpu: false
		dx_timeout: "7D0H00M"
	}

        output {
                File res = "sugen_res.wald.out"
		File system_resource_usage = "system_resource_usage.log"
		File process_resource_usage = "process_resource_usage.log"
        }
}

task standardize_output {

	File resfile
	String exposure

	command {
		python3 /format_sugen_output.py ${resfile} ${exposure}
	}

	runtime {
		docker: "quay.io/large-scale-gxe-methods/sugen-workflow"
		memory: "2 GB"
	}

        output {
                File res_fmt = "results.fmt"
	}
}

task cat_results {

	Array[File] results_array

	command {
		head -1 ${results_array[0]} > all_results.txt && \
			for res in ${sep=" " results_array}; do tail -n +2 $res >> all_results.txt; done
	}
	
	runtime {
		docker: "quay.io/large-scale-gxe-methods/sugen-workflow"
		disks: "local-disk 5 HDD"
	}

	output {
		File all_results = "all_results.txt"
	}
}
			

workflow run_sugen {

	Array[File] genofiles
	File phenofile
	String sample_id_header
	String outcome
	Boolean binary_outcome
	String exposure_names
	String? covar_names = ""
	String? delimiter = ","
	String? missing = "NA"
	Boolean? robust = true
	Int? memory = 10
	Int? disk = 20
	Int? monitoring_freq = 1

	Int ppmem = 2 * ceil(size(phenofile, "GB")) + 1

	call process_phenos {
		input:
			phenofile = phenofile,
			sample_id_header = sample_id_header,
			outcome = outcome,
			exposure = exposure_names,
			covar_names = covar_names,
			delimiter = delimiter,
			missing = missing,
			ppmem = ppmem
	}
	
	scatter (i in range(length(genofiles))) {
		call run_interaction {
			input:
				genofile = genofiles[i],
				phenofile = process_phenos.pheno_fmt,
				sample_id_header = sample_id_header,
				outcome = outcome,
				binary_outcome = binary_outcome,
				exposure = exposure_names,
				covar_names = covar_names,
				robust = robust,
				memory = memory,	
				disk = disk,
				monitoring_freq = monitoring_freq
		}
	}

	scatter (resfile in run_interaction.res) {
		call standardize_output {
			input:
				resfile = resfile,
				exposure = exposure_names
		}
	}	

	call cat_results {
		input:
			results_array = standardize_output.res_fmt
	}

        output {
                File results = cat_results.all_results
		Array[File] system_resource_usage = run_interaction.system_resource_usage
		Array[File] process_resource_usage = run_interaction.process_resource_usage
	}

	parameter_meta {
		genofiles: "Array of genotype filepaths in bgzipped VCF format (should contain a dosage/'DS' field)."
		phenofile: "Phenotype filepath."	
		sample_id_header: "Column header name of sample ID in phenotype file."
		outcome: "Column header name of phenotype data in phenotype file."
		binary_outcome: "Boolean: is the outcome binary? Otherwise, quantitative is assumed."
		exposure_names: "Column header name(s) of the exposures for genotype interaction testing (space-delimited). Only one exposures is currently allowed."
		covar_names: "Column header name(s) of any covariates for which only main effects should be included (space-delimited). This set should not overlap with exposure_names."
		delimiter: "Delimiter used in the phenotype file."
		missing: "Missing value key of phenotype file."
		robust: "Boolean: should robust (a.k.a. sandwich/Huber-White) standard errors be used?"
		memory: "Requested memory for the interaction testing step (in GB)."
		disk: "Requested disk space for the interaction testing step (in GB)."
		monitoring_freq: "Delay between each output for process monitoring (in seconds). Default is 1 second."
	}

	meta {
		author: "Kenny Westerman"
		email: "kewesterman@mgh.harvard.edu"
		description: "Run interaction tests using the SUGEN package and return summary statistics for 1-DF and 2-DF tests."
	}
}
