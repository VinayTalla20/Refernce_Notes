from flask import Flask, jsonify, request
from pymongo import MongoClient
import logging
from bson import ObjectId, Binary, json_util
from bson.json_util import dumps  # Import BSON utility for JSON serialization
import datetime
import os
import json

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S')

logger = logging.getLogger(__name__)

app = Flask(__name__)
port = os.getenv("PORT", 5000)

# MongoDB connection details
MONGODB_ROOT_USERNAME = os.getenv("MONGODB_ROOT_USERNAME", "")
MONGODB_ROOT_PASSWORD = os.getenv("MONGODB_ROOT_PASSWORD", "")

MONGODB_CONNECTIONSTRING = f"mongodb://{MONGODB_ROOT_USERNAME}:{MONGODB_ROOT_PASSWORD}@mangodb-disk-service.syndication:27017/admin"

client = None
try:
    if MONGODB_ROOT_USERNAME and MONGODB_ROOT_PASSWORD:
        client = MongoClient(MONGODB_CONNECTIONSTRING)
        client.server_info()  # Ensures connection
        logger.info("Successfully connected to MongoDB")
    else:
        raise ValueError("MongoDB credentials are missing")
except Exception as e:
    logger.error(f"Failed to connect to MongoDB: {e}")
    client = None
    
# Root route to test basic connection
@app.route('/')
def home():
    logger.info('Home route accessed')
    return 'API is working!'


@app.route('/healthz')
def healthCheck():
    logger.info('MongoDB Datasource is Alive')
    return 'MongoDB Datasource is Alive!'

# Helper function to serialize MongoDB documents


def serialize_document(doc):
    """Recursively serialize MongoDB document fields for JSON compatibility."""
    if isinstance(doc, dict):
        for key, value in doc.items():
            if isinstance(value, ObjectId):
                doc[key] = str(value)
            elif isinstance(value, Binary):
                doc[key] = value.hex()  # Converts Binary to hex string
            elif isinstance(value, datetime.datetime):
                doc[key] = value.isoformat()  # Converts datetime to ISO format
            elif isinstance(value, (bytes, bytearray)):
                doc[key] = value.decode("utf-8", errors="ignore")
            elif isinstance(value, list):
                doc[key] = [serialize_document(item) if isinstance(
                    item, (dict, list)) else item for item in value]
            elif isinstance(value, dict):
                # Recursively serialize nested dictionaries
                doc[key] = serialize_document(value)
    return doc

# Route to list all databases


@app.route('/databases', methods=['GET'])
def list_databases():
    try:
        databases = client.list_database_names()
        logger.info(f"Databases listed: {databases}")
        return jsonify({'databases': databases})
    except Exception as e:
        logger.error(f"Error while listing databases: {e}")
        return jsonify({'error': str(e)}), 500

# Route to list collections in a specific database


@app.route('/collections', methods=['GET'])
def list_collections():
    try:
        db_name = request.args.get('db')
        if not db_name:
            logger.warning('Database name is missing')
            return jsonify({'error': 'Database name is required as a query parameter: ?db=<database_name>'}), 400

        if db_name not in client.list_database_names():
            logger.warning(f'Database "{db_name}" not found')
            return jsonify({'error': f'Database "{db_name}" not found'}), 404

        db = client[db_name]
        collections = db.list_collection_names()
        logger.info(f"Collections in database {db_name}: {collections}")
        return jsonify({'database': db_name, 'collections': collections})
    except Exception as e:
        logger.error(f"Error while listing collections: {e}")
        return jsonify({'error': str(e)}), 500

# Endpoint to get data from a specific collection


@app.route('/collection_data', methods=['GET'])
def getDocumentsUsingDBandCollection():
    try:
        db_name = request.args.get('db')
        collection_name = request.args.get('collection')
        startTime = request.args.get('startTime')
        endTime = request.args.get('endTime')

        db_client = client[db_name]
        db_collection = db_client[collection_name]
        logger.info(f"Getting Audit Logs from Start Time {startTime} to End Time {endTime} for the Database {db_name} and collection {collection_name}")
            
        start_time_obj = datetime.datetime.fromisoformat(startTime.replace("Z", "+00:00"))
        end_time_obj = datetime.datetime.fromisoformat(endTime.replace("Z", "+00:00"))
        
        required_data = db_collection.find({"lastUpdatedTime": {"$gte": start_time_obj, "$lte": end_time_obj}})

        DeserilizedJson = dumps(required_data)

        jsonData = {
            "Documents": json.loads(DeserilizedJson)
        }

        return jsonData

    except Exception as e:
        logger.error(f"Error while fetching data from collection: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/getAuditLogs', methods=['GET'])
def getDocumentsUsingDBandCollectionWithOperations():
    try:
        db_name = request.args.get('db')
        collection_name = request.args.get('collection')
        operationType = request.args.get('operation')
        startTime = request.args.get('startTime')
        endTime = request.args.get('endTime')

        db_client = client[db_name]
        db_collection = db_client["system.profile"]

        jsonData: str
        insertions, userInfo = [], []

        if operationType == "insert":
            logger.info(f"Getting Audit Logs from Start Time {startTime} to End Time {endTime} for the Database {db_name} and collection {collection_name}")
            
            start_time_obj = datetime.datetime.fromisoformat(startTime.replace("Z", "+00:00"))
            end_time_obj = datetime.datetime.fromisoformat(endTime.replace("Z", "+00:00"))
            
            
            # /getAuditLogs?collection=auditCollection&db=coveoconnector&endTime=2025-01-15T12:45:45.896Z&operation=insert&startTime=2025-01-14T12:45:45.896Z
            
            
            required_data = db_collection.find({
                                "$and": [
                                    {"ts": {"$gte": start_time_obj, "$lte": end_time_obj}},                     # Time range
                                    {"ns": f"{db_name}.{collection_name}"},                            # Namespace
                                    {"op": operationType}                             # Operation type
                                ]
                                            })

            
            DeserilizedJson = dumps(required_data)

            for data in json.loads(DeserilizedJson):
                logger.info(data)
                insertions.append(data["command"]["documents"])
                userInfo.append(data["user"])

                logger.info(insertions)
                logger.info(userInfo)

            jsonData = {
                "InsertedFields": insertions,
                "UserInfo": userInfo
            }

            return jsonify(jsonData)

        elif operationType == "remove":

            start_time_obj = datetime.datetime.fromisoformat(startTime.replace("Z", "+00:00"))
            end_time_obj = datetime.datetime.fromisoformat(endTime.replace("Z", "+00:00"))
            
            
            # /getAuditLogs?collection=auditCollection&db=coveoconnector&endTime=2025-01-15T12:45:45.896Z&operation=insert&startTime=2025-01-14T12:45:45.896Z
            
            
            required_data = db_collection.find({
                                "$and": [
                                    {"ts": {"$gte": start_time_obj, "$lte": end_time_obj}},                     # Time range
                                    {"ns": f"{db_name}.{collection_name}"},                            # Namespace
                                    {"op": operationType}                             # Operation type
                                ]
                                            })

            DeserilizedJson = dumps(required_data)

            for data in json.loads(DeserilizedJson):
                logger.info(data)
                insertions.append(data["command"]["q"])
                userInfo.append(data["user"])

                logger.info(insertions)
                logger.info(userInfo)

            jsonData = {
                "RemovedFields": insertions,
                "UserInfo": userInfo
            }

            return jsonify(jsonData)

        elif operationType == "update":

            start_time_obj = datetime.datetime.fromisoformat(startTime.replace("Z", "+00:00"))
            end_time_obj = datetime.datetime.fromisoformat(endTime.replace("Z", "+00:00"))
            
            
            # /getAuditLogs?collection=auditCollection&db=coveoconnector&endTime=2025-01-15T12:45:45.896Z&operation=insert&startTime=2025-01-14T12:45:45.896Z
            
            
            required_data = db_collection.find({
                                "$and": [
                                    {"ts": {"$gte": start_time_obj, "$lte": end_time_obj}},                     # Time range
                                    {"ns": f"{db_name}.{collection_name}"},                            # Namespace
                                    {"op": operationType}                             # Operation type
                                ]
                                            })

            DeserilizedJson = dumps(required_data)

            for data in json.loads(DeserilizedJson):
                logger.info(data)
                insertions.append(data["command"]["u"])
                userInfo.append(data["user"])

                logger.info(insertions)
                logger.info(userInfo)

            jsonData = {
                "UpdatedFields": insertions,
                "UserInfo": userInfo
            }

            return jsonify(jsonData)

        else:
            return jsonify([])

    except Exception as e:
        logger.error(f"Error while fetching data from collection: {e}")
        return jsonify({'error': str(e)}), 500


# Start the Flask API
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=port)
