
ZIP_NAME = wazuh_to_amazon_security_lake
VIRTUAL_ENV = .venv

# Main target
pack: pack_deps pack_src

.ONESHELL:
pack_deps: $(VIRTUAL_ENV)
	@cd .venv/lib/python3.9/site-packages
	@zip -r ../../../../$(ZIP_NAME).zip .

.ONESHELL:
$(VIRTUAL_ENV):
	$(error Missing virtual environment, please install it with:
		python3 -m venv $(VIRTUAL_ENV)
		source $(VIRTUAL_ENV)/bin/activate
		pip install -r requirements.aws.txt
	)

.ONESHELL:
pack_src:
	@cd src
	@zip ../$(ZIP_NAME).zip lambda_function.py wazuh_ocsf_converter.py
	@zip ../$(ZIP_NAME).zip models -r

clean:
	@rm -rf $(VIRTUAL_ENV)
	@py3clean .