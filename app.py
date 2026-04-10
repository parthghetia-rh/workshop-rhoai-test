import os
from openai import OpenAI
import httpx
import warnings
# Suppress the ugly "InsecureRequestWarning" so the developers' output is clean
warnings.filterwarnings("ignore")

print("--- Initializing Client ---")

# We create a custom HTTP client that ignores the internal self-signed certificate (like curl -k)
custom_http_client = httpx.Client(verify=False)

# The client will automatically use the OPENAI_BASE_URL from your devfile
client = OpenAI(
    http_client=custom_http_client
)

MODEL_NAME = "workshop-maas-model" 

def run_prompt():
    print(f"--- Sending request to local {MODEL_NAME} on OpenShift AI ---")
    
    try:
        response = client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": "You are a helpful coding assistant."},
                {"role": "user", "content": "Write a python function to reverse a string."}
            ],
            max_tokens=100
        )
        
        print("\nResponse from Model:")
        print(response.choices[0].message.content)
        
    except Exception as e:
        print(f"\nError connecting to the model: {e}")

if __name__ == "__main__":
    run_prompt()