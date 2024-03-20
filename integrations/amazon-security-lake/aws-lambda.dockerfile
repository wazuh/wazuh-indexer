# docker build --platform linux/amd64 --no-cache -f aws-lambda.dockerfile -t docker-image:test .
# docker run --platform linux/amd64 -p 9000:8080 docker-image:test

FROM public.ecr.aws/lambda/python:3.9

# Copy requirements.txt
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN pip install -r requirements.txt

# Copy function code
COPY src ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "run.lambda_handler" ]