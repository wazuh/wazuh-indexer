## Amazon Security Lake Unit Tests

This directory contains unit tests for the Amazon Security Lake integration.

## How to run

1. Start a virtual environment:

```shell
python3 -m venv venv
source venv/bin/activate
```

2. Install the requirements:

```shell
pip install -r requirements.txt
```

3. Run the tests:

```shell
pytest -v
```

Execution example:

```shell
% pytest -v
================================================================= test session starts ==================================================================
platform darwin -- Python 3.13.0, pytest-8.3.4, pluggy-1.5.0 -- /Users/quebim_wz/IdeaProjects/wazuh-indexer/integrations/amazon-security-lake/venv/bin/python3.13
cachedir: .pytest_cache
rootdir: /Users/quebim_wz/IdeaProjects/wazuh-indexer/integrations/amazon-security-lake/tests
configfile: pytest.ini
collected 7 items                                                                                                                                      

test_lambda_function.py::test_lambda_handler PASSED                                                                                              [ 14%]
test_lambda_function.py::test_assume_role PASSED                                                                                                 [ 28%]
test_lambda_function.py::test_get_s3_client PASSED                                                                                               [ 42%]
test_lambda_function.py::test_get_events PASSED                                                                                                  [ 57%]
test_lambda_function.py::test_write_parquet_file PASSED                                                                                          [ 71%]
test_lambda_function.py::test_upload_to_s3 PASSED                                                                                                [ 85%]
test_lambda_function.py::test_get_full_key PASSED                                                                                                [100%]

================================================================== 7 passed in 0.59s ===================================================================
```