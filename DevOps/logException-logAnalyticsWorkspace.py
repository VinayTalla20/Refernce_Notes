import os
import re
import smtplib
import time
import shutil
import pandas as pd
from datetime import datetime, timezone, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from azure.monitor.query import LogsQueryClient, LogsQueryStatus
from azure.core.exceptions import HttpResponseError
from azure.identity import  DefaultAzureCredential, CertificateCredential
import base64
from azure.keyvault.secrets import SecretClient


TENANT_ID = os.getenv("TENANT_ID")
# KEYVAULT_MANAGED_IDENTITY_CLIENT_ID = os.getenv("KEYVAULT_MANAGED_IDENTITY_CLIENT_ID")
PME_CLIENT_ID = os.getenv("PME_CLIENT_ID")
CRON_PASSWD = os.getenv("CRON_PASSWD")
WORKSPACE_ID = os.getenv("WORKSPACE_ID")
REQUIRED_MAILS = os.getenv("REQUIRED_MAILS")
CLUSTER_ENV = os.getenv("CLUSTER_ENV")
# KEYVAULT_URL = os.getenv("KEYVAULT_URL")
# CERT_NAME = os.getenv("CERT_NAME")

# below is Function is used for Cross Tenat Auth iff One Cert domain Certificate is registered in Crop Tenant

# def get_cert(KEYVAULT_URL, CERT_NAME):
#     credential = DefaultAzureCredential(managed_identity_client_id=KEYVAULT_MANAGED_IDENTITY_CLIENT_ID)
#     secret_client = SecretClient(vault_url=KEYVAULT_URL, credential=credential)    
#     cert_secret = secret_client.get_secret(CERT_NAME).value
#     return base64.b64decode(cert_secret)

credential = CertificateCredential(TENANT_ID, PME_CLIENT_ID, certificate_path=os.getenv("CROSSTENANT_CERTIFICATE_SECUREFILEPATH"), send_certificate_chain=True)

client = LogsQueryClient(credential)

container_id_Query = """ContainerLogV2 | where PodNamespace contains "syndication" | where LogMessage matches regex ".Exception:" | where TimeGenerated > ago(24h)| summarize count() by ContainerId | project ContainerId """

required_container_ids = []
final_timeGenerated = []
final_container_ids = []
required_time = None
before_time = None
final_pod_names = []
filename = None
csv_filenames = []
extracted_logentries = []
required_logentries = []
extractedLogTime = []
SEND_MAILS = []
body_pod_name = []
body_log_entries = []
files = []
zip_file_name = "logFiles.zip"

# To get list of mails
mail = REQUIRED_MAILS.split(",")

for to_mails in mail:
    SEND_MAILS.append(to_mails)

# smtp connections

smtp_server = "smtp.office365.com"
smtp_port = 587
username = "cron@itdtech.com"
password = f"{CRON_PASSWD}"
from_addr = "cron@itdtech.com"
to_addr = SEND_MAILS
subject = f"{CLUSTER_ENV} Exceptions"

body = "<p>Hi Team,</p><br><p> Below are the pods with exceptions from the last 24 hours. Please find the attached logs for further analysis.</p><br>"

body += "<p>Pod's with Exceptions:</p><br>"


# method remove container_ids with Status CrashLoopBackOff
def remove_crashloopbackoff(container_id):
    print("checking container status Crash Loop back off Container:", container_id)
    running_containers_query = f""" 
                    KubePodInventory
                    | where ContainerID contains "{container_id}"
                    | summarize count() by ContainerRestartCount
                    | project ContainerRestartCount
                    """

    try:
        time.sleep(5)
        response = client.query_workspace(
            workspace_id=f"{WORKSPACE_ID}",
            query=running_containers_query,
            timespan=None

        )
        if response.status == LogsQueryStatus.PARTIAL:
            error = response.partial_error
            data = response.partial_data
            print(error)
        elif response.status == LogsQueryStatus.SUCCESS:
            data = response.tables
        for container_table in data:
            get_running_values = pd.DataFrame(data=container_table.rows, columns=container_table.columns)
            # Set display options to show all rows and columns
            pd.set_option("display.max_rows", None)
            pd.set_option("display.max_columns", None)
            pd.set_option("display.width", None)
            pd.set_option("display.max_colwidth", None)

            print("size of response", get_running_values.size)
            restarts_count = pd.DataFrame(columns=['ContainerRestartCount'])
            print("restart count column", restarts_count)
            if get_running_values.size == 0:
                print("empty response from the query or no data")

            else:

                if get_running_values.values[0][0] >= 15:
                    print(len(required_container_ids))
                else:
                    print(f"The ContainerID {container_id} is not in state of CrashLoopBackOff,"
                          f" so appending to running containers array")
                    required_container_ids.append(container_id)
                # print("Container Status:" ,get_running_values.values)
                # if "CrashLoopBackOff" in get_running_values.values and "waiting" in get_running_values.values:
                #     #print(f"Container  {find_carshloopback} is in CrashLoopBackOff")
                #     required_container_ids.remove(find_carshloopback)
                #     #print(len(required_container_ids))


    except HttpResponseError as err:
        print("Something fatal happened:")
        print(err)


try:
    response = client.query_workspace(
        workspace_id=f"{WORKSPACE_ID}",
        query=container_id_Query,
        timespan=None

    )
    if response.status == LogsQueryStatus.PARTIAL:
        error = response.partial_error
        data = response.partial_data
        print(error)
    elif response.status == LogsQueryStatus.SUCCESS:
        data = response.tables
    for table in data:
        df = pd.DataFrame(data=table.rows, columns=table.columns)
        # Set display options to show all rows and columns
        pd.set_option("display.max_rows", None)
        pd.set_option("display.max_columns", None)
        pd.set_option("display.width", None)
        pd.set_option("display.max_colwidth", None)

    for container_ids in df.values:
        for container_id in container_ids:
            print("Appending running containers:", container_id)
            remove_crashloopbackoff(container_id)


except HttpResponseError as err:
    print("Something fatal happened:")
    print(err)


# method  to get podname

def podname(container_id):
    pod_name = None

    Pod_Query = f""" KubePodInventory | where ContainerID contains "{container_id}" | summarize count() by Name | project Name"""

    try:
        response = client.query_workspace(
            workspace_id=f"{WORKSPACE_ID}",
            query=Pod_Query,
            timespan=None

        )
        if response.status == LogsQueryStatus.PARTIAL:
            error = response.partial_error
            data = response.partial_data
            print(error)
        elif response.status == LogsQueryStatus.SUCCESS:
            data = response.tables
        for pod_table in data:
            pod_details = pd.DataFrame(data=pod_table.rows, columns=pod_table.columns)
            # Set display options to show all rows and columns
            pd.set_option("display.max_rows", None)
            pd.set_option("display.max_columns", None)
            pd.set_option("display.width", None)
            pd.set_option("display.max_colwidth", None)

            for pod in pod_details["Name"]:
                pod_name = pod


    except HttpResponseError as err:
        print("Something fatal happened:")
        print(err)

    return pod_name


for get_container_id in required_container_ids:

    Time_Generation_Query = f"""ContainerLogV2 | where LogMessage matches regex ".Exception:" | where ContainerId contains "{get_container_id}" | where TimeGenerated > ago(24h) | sort by TimeGenerated asc   | project LogMessage """

    try:
        response = client.query_workspace(
            workspace_id=f"{WORKSPACE_ID}",
            query=Time_Generation_Query,
            timespan=None

        )
        if response.status == LogsQueryStatus.PARTIAL:
            error = response.partial_error
            data = response.partial_data
            print(error)
        elif response.status == LogsQueryStatus.SUCCESS:
            data = response.tables
        for table in data:
            time_generation_details = pd.DataFrame(data=table.rows, columns=table.columns)
            # Set display options to show all rows and columns
            pd.set_option("display.max_rows", None)
            pd.set_option("display.max_columns", None)
            pd.set_option("display.width", None)
            pd.set_option("display.max_colwidth", None)

            logentry = time_generation_details["LogMessage"]

            # deduplicating elements in Array by spliting string at "Exception:"
            for all_logentries in logentry.values:
                # print("Log Entry",all_logentries)
                result = re.search(r'(?:\w+\.)+\w+Exception:', all_logentries)
                if result:
                    extracted_string = result.group(0)

                    extracted_logentries.append(extracted_string)

        # Deduplicating Extracted LogEntries
        for logentries in extracted_logentries:
            if logentries not in required_logentries and ")" not in logentries and "," not in logentries:
                required_logentries.append(logentries)
        extracted_logentries.clear()
        # print("Finally after deDuplicating", required_logentries, "Array length", len(required_logentries))

        # To get Time Generation for Specific Log

        for pass_logentry in required_logentries:

            Exception_Query = f"""ContainerLogV2 | where LogMessage contains "{pass_logentry}" | where ContainerId contains "{get_container_id}" | where TimeGenerated > ago(24h) | sort by TimeGenerated asc | take 1 | project TimeGenerated"""

            try:
                response = client.query_workspace(
                    workspace_id=f"{WORKSPACE_ID}",
                    query=Exception_Query,
                    timespan=None

                )
                if response.status == LogsQueryStatus.PARTIAL:
                    error = response.partial_error
                    data = response.partial_data
                    print(error)
                elif response.status == LogsQueryStatus.SUCCESS:
                    data = response.tables
                for table in data:
                    Exception_time_generation_details = pd.DataFrame(data=table.rows, columns=table.columns)
                    # Set display options to show all rows and columns
                    pd.set_option("display.max_rows", None)
                    pd.set_option("display.max_columns", None)
                    pd.set_option("display.width", None)
                    pd.set_option("display.max_colwidth", None)

                    for logtime in Exception_time_generation_details["TimeGenerated"]:
                        extractedLogTime.append(logtime)

                        required_time = str(logtime)

                        if "." in required_time:
                            required_time = required_time.split(".")[0]
                        else:
                            required_time = required_time.split("+")[0]

                        required_time = datetime.strptime(required_time, '%Y-%m-%d %H:%M:%S') + timedelta(seconds=10)
                        required_time.strftime('%Y-%m-%d %H:%M:%S')

                        # print("Required time", required_time)

                        before_time = datetime.strptime(str(required_time), '%Y-%m-%d %H:%M:%S') - timedelta(minutes=1)
                        before_time.strftime('%Y-%m-%d %H:%M:%S')

                        # print("Time before 1 minute", before_time)

                # get POD names using ContainerID's and calling podname method

                required_podName = podname(container_id=f"{get_container_id}")

                now = datetime.now().strftime("%Y-%m-%d")
                body_pod_name.append(required_podName)
                body_log_entries.append(pass_logentry)
                filename = f"{required_podName}-Exceptions_{now}.txt"
                # print("file name", filename)

                # To get Logs for Specific Exception in the Time Frame of 1 minute

                container_Logs_Query = f"""ContainerLogV2 | where ContainerId contains "{get_container_id}" | where TimeGenerated between (datetime("{before_time}") .. datetime("{required_time}")) | project LogMessage """

                try:
                    response = client.query_workspace(
                        workspace_id=f"{WORKSPACE_ID}",
                        query=container_Logs_Query,
                        timespan=None

                    )
                    if response.status == LogsQueryStatus.PARTIAL:
                        error = response.partial_error
                        data = response.partial_data
                        print(error)
                    elif response.status == LogsQueryStatus.SUCCESS:
                        data = response.tables
                    for table in data:
                        container_log_details = pd.DataFrame(data=table.rows, columns=table.columns)
                        # Set display options to show all rows and columns
                        pd.set_option("display.max_rows", None)
                        pd.set_option("display.max_columns", None)
                        pd.set_option("display.width", None)
                        pd.set_option("display.max_colwidth", None)

                        print(
                            f"Logs From {get_container_id} and {required_podName} for Log Entry {pass_logentry} are stored in {filename} from {before_time} to {required_time}")

                        container_log_details.to_csv(filename, mode='a', index=False,
                                                     header=not os.path.exists(filename))

                except HttpResponseError as err:
                    print("Something fatal happened:")
                    print(err)

            except HttpResponseError as err:
                print("Something fatal happened:")
                print(err)

        # bullet_list = "\n".join([f"- {required_podName}   {required_logentries} \n"])
        # body += bullet_list
        required_logentries.clear()
        csv_filenames.append(filename)

    except HttpResponseError as err:
        print("Something fatal happened:")
        print(err)

# Email configuration


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
    print(f"The file {file_size} has size {size} bytes")
    single_file_size = int(size)
    total_file_sizes.append(size)
    total_file_size = single_file_size + total_file_size

print(f"The total file count is {no_of_files} and size is {total_file_size}")

# for csv_file in files:
#     with open(csv_file, "rb") as file:
#         part = MIMEBase("application", "octet-stream")
#         part.set_payload(file.read())
#     encoders.encode_base64(part)
#     part.add_header("Content-Disposition", f"attachment; filename= {csv_file}")
#     message.attach(part)
destination_folder = "LogFiles"
os.makedirs(destination_folder, exist_ok=True)
print("All Files are appending log files:", files)
for csv_file in files:

    if os.path.exists(f"{destination_folder}""/"f"{csv_file}"):
        print(f"File already exists {destination_folder}/{csv_file}")
    
    else:
        shutil.move(csv_file, destination_folder)

shutil.make_archive("AllPodLogFiles", 'zip', destination_folder)

with open("AllPodLogFiles.zip", "rb") as file:
    part = MIMEBase("application", "zip")
    part.set_payload(file.read())
encoders.encode_base64(part)
part.add_header("Content-Disposition", f"attachment; filename= {zip_file_name}")
message.attach(part)

# pandas Dataframe


mail_exception_body = {
    "podNames": body_pod_name,
    "LogMessages": body_log_entries
}

body_table = pd.DataFrame(mail_exception_body)
body_table_html = body_table.to_html(index=False)
body += body_table_html
body += "<br><p>Thanks,<br> DevOps Team</p><br>"

# Attach the email body
message.attach(MIMEText(body, "html"))
# message.attach(MIMEText(body_table_html, "html"))


# # Send the email
with smtplib.SMTP(smtp_server, smtp_port) as server:
    server.starttls()
    server.login(user=username, password=password)
    if required_container_ids:
        server.send_message(message)
        print("Email with attachment sent successfully.")
    else:
        print("No Container IDs found for Exception")
