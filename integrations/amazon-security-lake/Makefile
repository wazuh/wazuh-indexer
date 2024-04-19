
ZIP_NAME = wazuh_to_amazon_security_lake
TARGET = package

# Main target
pack: pack_deps pack_src

.ONESHELL:
pack_deps: $(TARGET)
	cd $(TARGET)
	zip -r ../$(ZIP_NAME).zip .

.ONESHELL:
$(TARGET):
	docker run -v `pwd`:/src -w /src \
		python:3.12 \
		pip install \
		--platform manylinux2014_x86_64 \
		--target=$(TARGET) \
		--implementation cp \
		--python-version 3.12 \
		--only-binary=:all: --upgrade \
		-r requirements.aws.txt

.ONESHELL:
pack_src:
	@cd src
	@zip ../$(ZIP_NAME).zip lambda_function.py wazuh_ocsf_converter.py
	@zip ../$(ZIP_NAME).zip models -r

clean:
	@rm -rf $(TARGET)
	@py3clean .