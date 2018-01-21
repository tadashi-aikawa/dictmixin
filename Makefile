MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

.PHONY: $(shell egrep -oh ^[a-zA-Z0-9][a-zA-Z0-9_-]+: $(MAKEFILE_LIST) | sed 's/://')

-include .env

help: ## Print this help
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9][a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

#------

init: ## Install dependencies and create envirionment
		@echo Start $@
		@pipenv install -d
		@echo End $@

_clean-docs: ## Clean documentation
		@cd sphinx-docs && pipenv run make clean

build-docs: _clean-docs ## Build documentation
		@echo Start $@
		@cd sphinx-docs && pipenv run make html linkcheck
		@echo End $@

serve-docs: build-docs ## Serve documentation
		@echo Start $@
		@cd sphinx-docs/_build/html && pipenv run python -m http.server
		@echo End $@

_clean-package-docs: ## Clean package documentation
		@rm -rf docs/*

_package-docs: build-docs _clean-package-docs ## Package documentation
		@echo Start $@
		@cp -r sphinx-docs/_build/html/* docs/
		@touch docs/.nojekyll
		@echo End $@

test: ## Unit test
		@echo Start $@
		@pipenv run py.test -vv --cov-report=xml --cov=. tests/
		@echo End $@

doctest: ## Doc test
		@echo Start $@
		@pipenv run python -m doctest owlmixin/{__init__.py,transformers.py,owlcollections.py,owlenum.py,owloption.py,util.py} -v
		@echo End $@

release: init test doctest _package-docs ## Release (set version) (Not push anywhere)
		@echo Start $@

		@echo '1. Recreate `owlmixin/version.py`'
		@echo "__version__ = '$(version)'" > owlmixin/version.py

		@echo '2. Package documentation'
		@make _package-docs

		@echo '3. Staging and commit'
		git add owlmixin/version.py
		git add docs
		git commit -m ':package: Version $(version)'
		
		@echo '4. Tags'
		git tag $(version) -m $(version)
		
		@echo 'Success All!!'
		@echo 'Now you should only do `git push`!!'

		@echo End $@

_clean-package: ## Clean package
		@echo Start $@
		@rm -rf build dist owlmixin.egg-info
		@echo End $@

_package: _clean-package ## Package OwlMixin
		@echo Start $@
		@pipenv run python setup.py bdist_wheel
		@echo End $@

publish: _package ## ReciwPublish to PyPI (set version and env TWINE_USERNAME, TWINE_PASSWORD)
		@echo Start $@
		@pipenv run twine upload dist/owlmixin-$(version)-py3-none-any.whl
		@echo End $@
