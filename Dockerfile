FROM debian:stable

WORKDIR /usr/src/app

# Install base packages
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates git wget gnupg build-essential lsb-release g++ \
		automake autogen libtool cmake-data cmake unzip \
		libboost-all-dev libblas-dev libopenblas-dev libz-dev libssl-dev \
		libprotobuf17 protobuf-compiler libprotobuf-dev \
		python3-dev python3-pip python3-setuptools python3-websocket\
		pkg-config;

# Install Intel libraries
RUN set -eux; \
	wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB; \
	apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB; \
	sh -c 'echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list';\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		intel-mkl-64bit-2019.5-075; \
	rm -f GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB;

# Install Marian MT
# COMPILE_CPU and COMPILE_CUDA control CPU and GPU, respectively.
RUN set -eux; \
	git clone https://github.com/marian-nmt/marian marian; \
	cd marian; \
	git checkout 1.9.0; \
	cmake . -DCOMPILE_SERVER=on -DUSE_SENTENCEPIECE=on -DCOMPILE_CPU=on -DCOMPILE_CUDA=off; \
	make -j4; \
	install -m 755 marian /usr/local/bin/; \
	install -m 755 marian-server /usr/local/bin/; \
	install -m 755 marian-vocab /usr/local/bin/; \
	install -m 755 marian-decoder /usr/local/bin/; \
	install -m 755 marian-scorer /usr/local/bin/; \
	install -m 755 marian-conv /usr/local/bin/; \
	install -m 644 libmarian.a  /usr/local/lib/;

COPY . .

# Install python requirements.

# First wheel, because the others won't work without it set up.
RUN set -eux; \
	pip3 install wheel; \
	pip3 install -r requirements.txt

RUN set -eux; \
	bash fetch-models.sh; \
	python3 write_configuration.py > services.json;

EXPOSE 8888
CMD python3 server.py -c services.json -p 8888 --elg
