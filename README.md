# Azure Cloud Infrastructure for Image Description Web Application

This project aims to create an Azure-based infrastructure for a web application that enables users to upload images. Upon image upload, an Azure Function is triggered, leveraging Azure Computer Vision to extract a description of the image. This description is intended to be stored in Azure Cosmos DB and relayed back to the user via the web application.

```mermaid
flowchart LR
a(Web App)
b(Blob Storage)
c(Azure Function)
d(Cognitive Services Computer Vision)
e(Azure Cosmos DB)
a --Image upload--> b -- Trigger --> c --Image recognition--> d
c -- Description storage--> e --> a
```

## Project Status

As of the current iteration, the image description retrieval process through Azure Computer Vision within the Azure Function is functional. However, the implementation of the output binding to Azure Cosmos DB is pending. Several potential workarounds have been identified but have not yet been implemented.

## Next Steps

- Investigate and implement workarounds for enabling the output binding to Azure Cosmos DB.
- Further refine the integration between the Azure Function, Computer Vision, and Cosmos DB.
- Enhance the web application to display image descriptions retrieved from Cosmos DB.