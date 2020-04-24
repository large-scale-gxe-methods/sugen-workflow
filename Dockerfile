FROM ubuntu:latest

MAINTAINER Kenny Westerman <kewesterman@mgh.harvard.edu>

RUN apt-get update && apt-get install -y wget unzip make gcc g++ libz-dev
RUN wget https://github.com/dragontaoran/SUGEN/archive/master.zip \
	&& unzip master.zip \
	&& cd SUGEN-master \
	&& make
ENV SUGEN=/SUGEN-master/SUGEN

RUN apt-get update && apt-get install -y libbz2-dev liblzma-dev \
	&& wget https://github.com/samtools/htslib/releases/download/1.10.2/htslib-1.10.2.tar.bz2 \
	&& tar xvf htslib-1.10.2.tar.bz2 \
	&& cd htslib-1.10.2 \
	&& ./configure \
	&& make \
	&& make install

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y git python3 python3-pip libeigen3-dev
RUN pip3 install pandas

RUN apt-get update && apt-get install -y dstat atop

COPY format_sugen_phenos.py format_sugen_output.py /
