import azure.functions as func
import logging
from azure.cognitiveservices.vision.computervision import ComputerVisionClient
from azure.cognitiveservices.vision.computervision.models import VisualFeatureTypes
from msrest.authentication import CognitiveServicesCredentials
# from azure.cosmos import CosmosClient, PartitionKey

app = func.FunctionApp()

@app.cosmos_db_output(arg_name="doc", 
                      database_name="<cosmosdb_database>", #cosmosdb_database
                      container_name="<cosmosdb_container>", #cosmosdb_container
                      # create_if_not_exists=True,
                      connection="connectionStringSetting")

@app.blob_trigger(arg_name="blob", path="<container>/{name}", connection="AzureWebJobsStorage") #container

def blob_trigger_image_recognition(blob: func.InputStream, doc: func.Out[func.Document]):
    # Retrieve the image URL from the blob trigger
    image_url = blob.uri
    # Initialize the Computer Vision client. 
    subscription_key = "<vision_account_key>" # NOT SECURE (use env variables instead) #vision_account_key
    endpoint = "https://<vision_account_region>.api.cognitive.microsoft.com/" #vision_account_region
    credentials = CognitiveServicesCredentials(subscription_key)
    computer_vision_client = ComputerVisionClient(endpoint, credentials)



    # Analyze the image using Computer Vision
    image_description=analyze_image(computer_vision_client, image_url)
    logging.info("This is as far as I can get. Description: %s", image_description)


    # # The next line give me : {"Errors":["One of the specified inputs is invalid"]}
    # # I haven't found the data format required yet.
    # doc.set(func.Document.from_dict({"id":1,"text": "Hello World", "foo": "bar"}))


    # Possible workaround
    # Initialize Cosmos DB client
    # cosmos_client = CosmosClient("<cosmosdb_endpoint>","<cosmosdb_key>") #cosmosdb_endpoint, cosmosdb_key

    # # Get database and container
    # database = cosmos_client.get_database_client("<cosmosdb_database>") #cosmosdb_database
    # container = database.get_container_client("<cosmosdb_container>") #cosmosdb_container

    # Format output
    # item={}
    # item['name']=image_url
    # item['text']=image_description

    # Write data to Cosmos DB
    # imageDescription.set(func.SqlRow({
    #     "image_url": image_url,
    #     "description": image_description if image_description else "No description available"
    # }))

    # container.create_item(body=item)

def analyze_image(client, image_url):
    # Get text description of the image
    language = "en"
    max_descriptions = 1
    descriptions = client.describe_image(image_url, max_descriptions, language)

    # Process and log the image description results
    for caption in descriptions.captions:
        logging.info("Description: %s", caption.text)
        logging.info("Confidence: %f", caption.confidence)
        return caption.text
