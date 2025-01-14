#!/bin/bash

echo "Enter AWS_ACCESS_KEY_ID : "
read AWS_ACCESS_KEY_ID

echo "Enter AWS_SECRET_ACCESS_KEY : "
read AWS_SECRET_ACCESS_KEY


# Set environment variables
export NAME=devops25
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=ap-south-1

# Print confirmation
echo "Environment variables have been set:"
echo "NAME=$NAME"
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
echo "AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"