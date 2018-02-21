venv: venv/bin/activate
venv/bin/activate: requirements.txt
	test -d venv || python3 -m venv venv
	venv/bin/pip install -Ur requirements_dev.txt
	touch venv/bin/activate

test: venv
	venv/bin/python tests/test.py

destroy_db:
	venv/bin/python destroy_db.py

clean: venv destroy_db test
	rm -rf venv

run: venv
	venv/bin/python upload_run.py

lambda_cleanup:
	rm -f lambda_$(TAG)_deploy.zip
	rm -rf lambda_$(TAG)_deploy/

lambda_buckets:
	# TODO: Can We automate bucket logging here as well?
	aws s3 mb s3://login-gov-$(ENVIRONMENT)-redshift-secrets
	aws s3 cp redshift_secrets.yml s3://login-gov-$(ENVIRONMENT)-redshift-secrets/redshift_secrets.yml

lambda_build: lambda_cleanup
	docker run -v $(PWD):/build-analytics -it --rm ubuntu:artful bash build-analytics/build.sh $(TAG)
	git tag -a $(TAG) -m "Deployed from Makefile"
	git push origin --tags

lambda_release: clean lambda_build

lambda_deploy: lambda_release
	aws s3 cp lambda_$(TAG)_deploy.zip s3://tf-redshift-bucket-deployments/
	aws s3 cp $(PWD)/additional_dependencies/dependencies.zip s3://login-gov-analytics-dependencies/
	make lambda_cleanup
