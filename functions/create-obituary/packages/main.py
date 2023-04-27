
import boto3
import json
import requests
from requests_toolbelt.multipart import decoder
import base64
import os
import time
import hashlib

# Initialize DynamoDB client
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Obituaries-30133072")

# Initialize Cloudinary settings
ssm = boto3.client('ssm')


cloudinary_api_key_parameter = ssm.get_parameter(Name='/cloudinary/api_key', WithDecryption=True)
cloudinary_api_key = cloudinary_api_key_parameter['Parameter']['Value']

cloudinary_api_secret_parameter = ssm.get_parameter(Name='/cloudinary/api_secret', WithDecryption=True)
cloudinary_api_secret = cloudinary_api_secret_parameter['Parameter']['Value']

gpt_secret_key_param = ssm.get_parameter(Name='/chatgpt/api_key', WithDecryption=True)
gpt_secret_key = gpt_secret_key_param['Parameter']['Value']


polly_client = boto3.client('polly')

def create_query_string(body):
    query_string = ""
    for idx, (k, v) in enumerate(body.items()):
        query_string += f"{k}={v}" if idx == 0 else f"&{k}={v}"
    return query_string

def sort_dictionary(dictionary, exclude):
    return {k: v for k, v in sorted(dictionary.items(), key=lambda item: item[0]) if k not in exclude}

def generate_cloudinary_signature(body, cloudinary_api_secret):
    exclude = ["api_key", "resource_type", "cloud_name"]
    sorted_body = sort_dictionary(body, exclude)
    query_string = create_query_string(sorted_body)
    query_string_appended = f"{query_string}{cloudinary_api_secret}"
    hashed = hashlib.sha1(query_string_appended.encode())
    signature = hashed.hexdigest()
    return signature

def create_handler(event, context):
    try:
        body = event['body']
        if event['isBase64Encoded']:
            body = base64.b64decode(body)
        content_type = event["headers"]["content-type"]
        data = decoder.MultipartDecoder(body, content_type)
        obituary_data = [part.content for part in data.parts]

        # parse the obituary data
        name = obituary_data[1].decode()
        born_year = obituary_data[2].decode()
        died_year = obituary_data[3].decode()
        id =  obituary_data[4].decode()
        key = name + ".png"
        file_name = os.path.join("/tmp/", key)
        with open(file_name, "wb") as f:
            f.write(obituary_data[0])

        # generate the obituary text using ChatGPT
        chatgpt_url = 'https://api.openai.com/v1/completions'
        chatgpt_prompt = f'write an obituary about a fictional character named {name} who was born on {born_year} and died on {died_year}.'
        chatgpt_data = {
            "prompt": chatgpt_prompt,
            "max_tokens": 600,
            "model": "text-curie-001"
        }
        chatgpt_headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {gpt_secret_key}"
        }
        chatgpt_response = requests.post(chatgpt_url, data=json.dumps(chatgpt_data), headers=chatgpt_headers)
        chatgpt_obituary = chatgpt_response.json()['choices'][0]['text'].strip()

        # convert the obituary text to speech using Amazon Polly
        polly = boto3.client('polly')
        speech_response = polly.synthesize_speech(
            Text=chatgpt_obituary,
            OutputFormat='mp3',
            VoiceId='Joanna'
        )
        cloud_name = "dmfdo4mby"
        # upload the speech mp3 file to Cloudinary
        timestamp = str(int(time.time()))
        cloudinary_url = f"https://api.cloudinary.com/v1_1/{cloud_name}/video/upload"
        cloudinary_signature = generate_cloudinary_signature({"public_id" : name, "timestamp" : timestamp}, cloudinary_api_secret)
        cloudinary_payload = {
            "api_key": cloudinary_api_key,
            "public_id": name,
            "signature": cloudinary_signature,
            "timestamp": timestamp
        }
        cloudinary_files = {
            "file": speech_response['AudioStream']
        }
        cloudinary_audio_response = requests.post(cloudinary_url, data=cloudinary_payload, files=cloudinary_files)

        cloudinary_url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"
        # Upload image to cloudinary
        with open(file_name, "rb") as f:
            cloudinary_payload = {
                "api_key": cloudinary_api_key,
                "public_id": name,
                "signature": cloudinary_signature,
                "timestamp": timestamp
            }
            cloudinary_files = {
                "file": f
            }
            cloudinary_image_response = requests.post(cloudinary_url, data=cloudinary_payload, files=cloudinary_files)
        image_url = cloudinary_image_response.json()['url']

        # get the public URL of the uploaded speech mp3 file
        speech_url = cloudinary_audio_response.json()['url']

        # add the e_art:zorro enhancement to the image URL
        image_url = image_url.replace('/upload/', '/upload/e_art:zorro/')
        #create item to put
        item = {
            'id' : id,
            'name': name,
            'born_year': born_year,
            'died_year': died_year,
            'obituary': chatgpt_obituary,
            'speech_url': speech_url,
            'image_url': image_url
        }
        # create a new item in the DynamoDB table
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('Obituaries-30133072')
        table.put_item(
            Item=item
        )

        # return a success response
        response = {
            "statusCode": 200,
            "body": json.dumps(item),
            "headers": {
                "Content-Type": "application/json"
            }
        }
        return response

    except Exception as e:
        # return an error response
        response_body = {
            "message": "Error creating obituary",
            "error": str(e)
        }
        response = {
            "statusCode": 500,
            "body": json.dumps(response_body),
            "headers": {
                "Content-Type": "application/json"
            }
        }
    return response