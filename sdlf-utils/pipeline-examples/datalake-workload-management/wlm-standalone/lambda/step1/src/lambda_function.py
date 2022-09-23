import datetime
import json
import logging
import os
import urllib.parse
import uuid

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    try:

        type_event = event["body"]["type"]

        if type_event == "success":
            return {"statusCode": 200}
        else:
            raise Exception("Failure type encountered, sending message to SNS")

    except Exception as e:
        logger.error(e)
        raise e
