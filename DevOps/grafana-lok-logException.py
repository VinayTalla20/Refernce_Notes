import pytz
import re
import requests
import logging
import datetime
from datetime import timedelta
import pandas as pd
import numpy as np
import time
import os
import smtplib
import time
import shutil
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S')

logger = logging.getLogger(__name__)

def getPreviousDate(start_date):
    
    previous_date  = datetime.datetime.strptime(start_date, "%Y-%m-%dT%H:%M:%SZ") - timedelta(hours=int(REQUIRED_INTERVAL_HOURS))
    previous_date = previous_date.strftime("%Y-%m-%dT%H:%M:%SZ")
    logger.info(f"returning previous date {previous_date}")
    return previous_date



def logQLQueryBuilder(start_time, end_time, logqlQuery):
     
    url = f"{LOKI_DATASOURCE_HOST}/loki/api/v1/query_range"
    params = {
        "limit": 2000,
        "start": start_time,
        "end": end_time,
        "query": logqlQuery
    }
    
    response = requests.get(url, params=params, timeout=600)
    return response

def getExceptionLogEntries(start_time, end_time):
    
    url = f"{LOKI_DATASOURCE_HOST}/loki/api/v1/query_range"
    params = {
        "limit": 2000,
        "start": start_time,
        "end": end_time,
        "query": '{namespace="syndication"}|~ `.Exception:`'
    }
    response = requests.get(url, params=params, timeout=600)
    logger.info(f"{response.json}")
    
    if response.status_code == 200 and response.json()["data"]["result"]:
        setpodname_response = response.json()["data"]["result"]
        processExceptionLogEntries(logStreams=setpodname_response)
    else:
        logger.info(f"Error No Exception founds {response.json}")


def getPodNames(logStreams):
    
    requiredPodName = logStreams["pod"]
    podNames.append(requiredPodName)

def getLogExceptionEntriesForPod(podName):
     
    query = f'{{namespace="syndication", pod="{podName}"}}|~ `.Exception:`'
    response = logQLQueryBuilder(start_time, end_time, logqlQuery=query)
    getLogentriesWithExceptions = response.json()["data"]["result"][0]["values"]
    modifyLogMessages(getLogentriesWithExceptions)

    # logger.info(f"Specific exception  log for pod with pod name {podName}")


def modifyLogMessages(logMessages):
    for all_logentries in logMessages:
        # result = re.search(r'(\S+Exception:)', all_logentries[1])
        # result = re.search(r'\w+\.\w+\.\w+Exception:', all_logentries[1])
        result = re.search(r'(?:\w+\.)+\w+Exception:', all_logentries[1])
         
        if result:
            extracted_string = result.group(0)
            extractedLogEntries.append(extracted_string)


def processExceptionLogEntries(logStreams):
     
     for logExceptionStreams in logStreams:
        getPodNames(logStreams=logExceptionStreams["stream"])


def deduplicatingLogExceptions():
    requiredLogEntries.clear()
    for logentries in extractedLogEntries:
            if logentries not in requiredLogEntries and ")" not in logentries and "," not in logentries:
                logger.info(f"appending log exception_______: {logentries}")
                requiredLogEntries.append(logentries)


def getExceptionLogTimeForPod(podName, requiredLogEntries):
    logger.info(f"In method getExceptionLogTimeForPod----------  podName: {podName}, LogEntries: {requiredLogEntries}")
    query = f'{{namespace="syndication", pod="{podName}"}}|~ `{requiredLogEntries}`'
    logger.info(f"Passing query to get Time of Exception {query}")
    time.sleep(10)
    response = logQLQueryBuilder(start_time, end_time, logqlQuery=query)
    # logger.info("respnse :::::", response.json()["data"]["result"])
    # below time format is linux epouch time Ex: 1712924647505603343
    # logger.info("response for time stamp exception log------||||",response.json()["data"]["result"])
    if response.status_code == 200 and response.json()["data"]["result"]:
        linuxEpouchTime = (response.json()["data"]["result"][0]["values"][0][0])
        logger.info(f"Linux epouch time____: {linuxEpouchTime}")
        body_pod_name.append(podName)
        body_log_entries.append(requiredLogEntries)
        body_exception_timestamp.append(convertLinuxEpouchToHumanReadableTimeStamp(linuxEpouchTime))
        return convertToDateTimeFormat(linuxEpouchTime)
    else:
        logger.info(f"No Time found or no Exceptions {response.json}")

def convertLinuxEpouchToHumanReadableTimeStamp(linuxEpouchTime):
    convertToNanoSeconds = int(linuxEpouchTime)/ 1e9
    # Convert to datetime object
    dt_object = datetime.datetime.fromtimestamp(int(convertToNanoSeconds))

    # Format the datetime object (optional)
    formatted_date = dt_object.strftime("%Y-%m-%d %H:%M:%S")

    logger.info(f"Converted Linux Epouch Date {linuxEpouchTime} to HumanReadable Format: {formatted_date}")
    
    return formatted_date

def convertToDateTimeFormat(linuxEpouchTime):
        convertToNanoSeconds = int(linuxEpouchTime)/ 1e9
        utc_datetime = datetime.datetime.fromtimestamp(convertToNanoSeconds)

        # Add 1 minute to the datetime object
        utc_datetime += datetime.timedelta(minutes=1)

        # Convert the datetime object to a Unix epoch timestamp
        epoch_timestamp = int(utc_datetime.timestamp())

        
        # # convertToNanoSeconds = str(convertToNanoSeconds).split(".")[0]
        # logger.info("after converting Linux epouch time______:", linuxEpouchTime, convertToNanoSeconds)
        # # convert to date time format
        # formatted_time = datetime.datetime.fromtimestamp(int(convertToNanoSeconds))
        # requiredTimestamp = datetime.datetime.strptime(str(formatted_time), "%Y-%m-%d %H:%M:%S")
        # # utcRequiredTimestamp = requiredTimestamp - timedelta(hours=5, minutes=30)
        # # utcTimestampToPass = utcRequiredTimestamp.strftime('%Y-%m-%dT%H:%M:%SZ')
        # logger.info("Formatted TIME STAMP______:", requiredTimestamp)
        return [epoch_timestamp, linuxEpouchTime]



def createDataFrame(response, podName, filename):
        if response["data"]["result"]:
            logger.info(f"Appending Log to CSV files for the pod name {podName}")
            # logger.info("log create DataFrame_____:", response)
            nP_aarray = response["data"]["result"][0]["values"]
            array = np.array(nP_aarray)
            pd.set_option("display.max_rows", None)
            pd.set_option("display.max_columns", None)
            pd.set_option("display.width", None)
            pd.set_option("display.max_colwidth", None)
            # Pass the array to the pd.DataFrame() function
            df = pd.DataFrame(data=array, columns=["Timestamp", "Message"])
            df["Message"].to_csv(filename, mode='a', index=False, header=False)
        else:
            logger.info(f"log create DataFrame_____: {response}")
            logger.info(f"empty response so not Appending Log to CSV files for the pod name {podName}")


def customLogException(logMessage, start_time, end_time):
    if len(logMessage) != 0:
        for log in logMessage:
            logger.info(f"Passing Custom Log Exceptions: {log}")
            # frame log Query
            query = f'{{namespace="syndication"}}|~ `{log}`'
            # get Logs Response from the Loki
            response = logQLQueryBuilder(start_time, end_time, logqlQuery=query)
            logger.info(f"Custom Log Exception Response: {response.json()}")
            if  response.status_code == 200 and response.json()["data"]["result"]:
                for podNames in response.json()["data"]["result"]:
                    
                    getPodNamesForCustomLogException = podNames["stream"]["pod"]
                    getLogentriesWithCustomExceptions = response.json()["data"]["result"][0]["values"]
                    logger.info(f"****************** {getPodNamesForCustomLogException}")
                    requiredTimeCustomException = getExceptionLogTimeForPod(podName=getPodNamesForCustomLogException, requiredLogEntries=log)
                    
                    if requiredTimeCustomException is not None and len(requiredTimeCustomException) != 0:
                        podLogquery = f'{{namespace="syndication", pod="{getPodNamesForCustomLogException}"}}'
                        CustomExceptionPodLogResponse = logQLQueryBuilder(start_time=requiredTimeCustomException[1], end_time=requiredTimeCustomException[0], logqlQuery=podLogquery)
                        logger.info(f"Log From  time stamp {requiredTimeCustomException[1]} to {requiredTimeCustomException[0]} for podName {getPodNamesForCustomLogException} log exception Entry {log}")
                        if CustomExceptionPodLogResponse.status_code == 200 and CustomExceptionPodLogResponse.json()["data"]["result"]:
                            time.sleep(10)
                            now = datetime.datetime.now().strftime("%Y-%m-%d")
                            CustomExceptionFileName = f"{getPodNamesForCustomLogException}-CustomExceptions_{now}.txt"
                            csv_filenames.append(CustomExceptionFileName)
                            createDataFrame(response=CustomExceptionPodLogResponse.json(), podName=getPodNamesForCustomLogException, filename=CustomExceptionFileName)
                    else:
                        logger.info(f"Required Time is None for Custom Exception: {requiredTimeCustomException}")
                    
                    
            else:
                logger.info(f"No Logs Found for Exception {log}")

    else:
        logger.info(f"No Custom Log Exceptions found")


def sendMail(body):
     # Email configuration
    # To get list of mails
    mail = REQUIRED_MAILS.split(",")

    for to_mails in mail:
        SEND_MAILS.append(to_mails)

    smtp_server = "smtp.office365.com"
    smtp_port = 587
    to_addr = SEND_MAILS
    username = "cron@itdtech.com"
    from_addr = "cron@itdtech.com"
    password = f"{CRON_PASSWD}"

    # Create a multipart message
    message = MIMEMultipart()
    message["From"] = from_addr
    message["To"] = ", ".join(to_addr)
    message["Subject"] = subject

    files = csv_filenames
    no_of_files = len(csv_filenames)
    # get all files size
    total_file_size = 0
    total_file_sizes = []
    for file_size in files:
        size = os.path.getsize(file_size)
        logger.info(f"The file {file_size} has size {size} bytes")
        single_file_size = int(size)
        total_file_sizes.append(size)
        total_file_size = single_file_size + total_file_size

    logger.info(f"The total file count is {no_of_files} and size is {total_file_size}")

    destination_folder = "LogFiles"
    os.makedirs(destination_folder, exist_ok=True)
    logger.info(f"All Files are appending log files: {files}")
    for csv_file in files:

        if os.path.exists(f"{destination_folder}""/"f"{csv_file}"):
            logger.info(f"File already exists {destination_folder}/{csv_file}")
        
        else:
            shutil.move(csv_file, destination_folder)

    shutil.make_archive("AllPodLogFiles", 'zip', destination_folder)

    with open("AllPodLogFiles.zip", "rb") as file:
        part = MIMEBase("application", "zip")
        part.set_payload(file.read())
    encoders.encode_base64(part)
    part.add_header("Content-Disposition", f"attachment; filename= {zip_file_name}")
    message.attach(part)

    logger.info(f"body Pod Names in Mail Body {body_pod_name}")
    logger.info(f"body Pod logs entries in Mail Body {body_log_entries}")
    # pandas Dataframe
    mail_exception_body = {
        "podNames": body_pod_name,
        "LogMessages": body_log_entries,
        "ExceptionTimeStamp(YYYY-MM-DD HH:MM:SS)": body_exception_timestamp
    }

    body_table = pd.DataFrame(mail_exception_body)
    body_table_html = body_table.to_html(index=False)
    body += body_table_html
    body += "<br><p>Thanks,<br> DevOps Team</p><br>"

    # Attach the email body
    message.attach(MIMEText(body, "html"))
    # # Send the email
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()
        server.login(user=username, password=password)
        if body_pod_name:
            server.send_message(message)
            logger.info("Email with attachment sent successfully.")
        else:
            logger.info("No Container IDs found for Exception")


if __name__ == "__main__":
    podNames = []
    CLUSTER_ENV = os.getenv("CLUSTER_ENV")
    CRON_PASSWD = os.getenv("CRON_PASSWD")
    REQUIRED_INTERVAL_HOURS : int = os.getenv("REQUIRED_INTERVAL_HOURS", 4)
    ITERATIONS_REQUIRED : int = os.getenv("ITERATIONS_REQUIRED", 6)
    REQUIRED_MAILS = os.getenv("REQUIRED_MAILS")
    LOKI_DATASOURCE_HOST = os.getenv("LOKI_DATASOURCE_HOST", "http://localhost:3100")
    customExceptionStrings = ["Exception:Read timed out"]
    logEntries = []
    requiredLogEntries = []
    extractedLogEntries = []
    csv_filenames = []
    body_pod_name = []
    body_log_entries = []
    body_exception_timestamp = []
    files = []
    SEND_MAILS = []
    zip_file_name = "logFiles.zip"
    subject = f"{CLUSTER_ENV} Exceptions"
    body = "<p>Hi Team,</p><br><p> Below are the pods with exceptions from the last 24 hours. Please find the attached logs for further analysis.</p><br>"
    body += "<p>Pod's with Exceptions:</p><br>"
    
    end_time = datetime.datetime.now(pytz.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    start_time = getPreviousDate(end_time)

    n = 0
    while n < int(ITERATIONS_REQUIRED):
        logger.info(f"n value is {n}")
        podNames.clear()
        logger.info(f"Get all Exception log Entries from specified interval from {start_time} to {end_time}")
        getExceptionLogEntries(start_time, end_time)
        # pass each exception pod name and get Relation Exception log
        for requiredPodName in podNames:
            # logger.info("Extracted Log Entry", extractedLogEntries)
            extractedLogEntries.clear()
            logger.info("------------------------------------------------------------")
            logger.info(f"working with the podName {requiredPodName}")
            getLogExceptionEntriesForPod(requiredPodName)
            deduplicatingLogExceptions()
            logger.info(f"after deduplicating_____: {requiredLogEntries}")
            for logEntries in requiredLogEntries:
                required_time = getExceptionLogTimeForPod(requiredPodName, logEntries)
                logger.info(f"required time____: {required_time}")

                logger.info("Passing log Exception mesages to get logs 30 seconds ahead of Exception")
                query = f'{{namespace="syndication", pod="{requiredPodName}"}}'
                logger.info(f"passing query for exception  logs :{query}")
                
                # time.sleep(10)
                # now = datetime.datetime.now().strftime("%Y-%m-%d")
                # filename = f"{requiredPodName}-Exceptions_{now}.txt"
                # csv_filenames.append(filename) 
                if required_time is not None and len(required_time) != 0:
                    response = logQLQueryBuilder(start_time=required_time[1], end_time=required_time[0], logqlQuery=query)
                    logger.info(f"Log From  time stamp {required_time[1]} to {required_time[0]} for podName {requiredPodName} log exception Entry {logEntries}")
                    if response.status_code == 200 and response.json()["data"]["result"]:
                        time.sleep(10)
                        now = datetime.datetime.now().strftime("%Y-%m-%d")
                        filename = f"{requiredPodName}-Exceptions_{now}.txt"
                        csv_filenames.append(filename) 
                        createDataFrame(response.json(), requiredPodName, filename=filename)
                else:
                    logger.info(f"Required Time is None: {required_time}")
        
        end_time = start_time
        start_time = getPreviousDate(start_time)
        logger.info(f"setting for start time {start_time} and end time {end_time} for next interval")
        n += 1
        time.sleep(60)
        logger.info("sleep for 1 minute")
        logger.info("**************************** while loop *****************************")
        # csv_filenames.append(filename) 
    
    # Logic for Custom Exceptions should be passed a array of values
    end_time = datetime.datetime.now(pytz.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    start_time = getPreviousDate(end_time)
    customNumber = 0
    while customNumber < int(ITERATIONS_REQUIRED):
        logger.info(f"setting for Custom Exception start time {start_time} and end time {end_time} for next interval")
        customLogException(logMessage=customExceptionStrings, start_time=start_time, end_time=end_time)
        
        end_time = start_time
        start_time = getPreviousDate(start_time)
        customNumber += 1
        
        logger.info(f"body Pod Names in Custom Exception {body_pod_name}")
        logger.info(f"body Pod log entries in Custom Exception {body_log_entries}")
        time.sleep(60)
        logger.info("sleep for 1 minute")
        logger.info("**************************** while loop for Custom Exception *****************************")
    
    sendMail(body)
