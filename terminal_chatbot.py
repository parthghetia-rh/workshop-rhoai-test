import os
import warnings
from openai import OpenAI
import httpx
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel

# Initialize the rich console for beautiful terminal UI
console = Console()

# Suppress the "InsecureRequestWarning" for the self-signed cluster certificate
warnings.filterwarnings("ignore")

console.print("[bold yellow]--- Initializing Connection to OpenShift AI ---[/bold yellow]")

# Create a custom HTTP client that ignores the internal self-signed certificate
custom_http_client = httpx.Client(verify=False, timeout=120.0)

# The client automatically uses OPENAI_BASE_URL and OPENAI_API_KEY from the devfile environment variables
client = OpenAI(
    http_client=custom_http_client
)

# 1. DYNAMICALLY FETCH AND PRINT THE MODEL
try:
    available_models = client.models.list()
    MODEL_NAME = available_models.data[0].id
    
    console.print("[bold green]✅ Successfully connected to the internal cluster network![/bold green]")
    console.print(f"[bold cyan]🤖 Active GPU Model:[/bold cyan] {MODEL_NAME}\n")
except Exception as e:
    console.print(f"[bold red]❌ Failed to connect to the model server.[/bold red]\nError: {e}")
    exit(1)

# Display a nice welcome banner
welcome_msg = """
**Type your message below.** If you are pasting multi-line code, press Enter, type `/send` on a new line, and press Enter again to submit!
Type `exit` or `quit` to end the session.
"""
console.print(Panel(Markdown(welcome_msg), title="🚀 OpenShift AI Terminal Chatbot", border_style="blue"))

# 2. INITIALIZE CHAT HISTORY
chat_history = [
    {"role": "system", "content": "You are an expert software engineer. You MUST wrap ALL code output inside Markdown triple-backticks (```python). Always provide a brief explanation of the problem before showing the fixed code."}
]

# 3. THE CHATBOT LOOP
while True:
    console.print("\n[bold green]You[/bold green] [dim](Type message or paste code. Type [/dim][bold yellow]/send[/bold yellow][dim] on a new line to submit):[/dim]")
    
    user_input_lines = []
    
    # Read multiple lines until the user types /send
    while True:
        try:
            line = input()
        except EOFError:
            break  # Failsafe: Catch Ctrl+D gracefully
            
        # Check if they typed the submit command
        if line.strip().lower() == '/send':
            break
            
        # Check if they just want to exit right away
        if line.strip().lower() in ['exit', 'quit'] and len(user_input_lines) == 0:
            user_input_lines.append(line)
            break
            
        user_input_lines.append(line)
        
    # Join all the pasted lines back together with newline characters
    user_input = "\n".join(user_input_lines).strip()
    
    # Skip empty submissions
    if not user_input:
        continue

    # Exit sequence
    if user_input.lower() in ['exit', 'quit']:
        console.print("[bold yellow]Ending session. Goodbye![/bold yellow]")
        break
        
    # SILENT FORMATTING INJECTION:
    # We append a strict instruction to the end of whatever the user typed.
    # The model sees this, but the user does not.
    formatted_user_input = user_input + "\n\nIMPORTANT: If your answer includes code, you MUST format it inside a markdown code block starting with ```python and ending with ```. Do not provide raw code without these backticks."

    # We append the original user input to the history so the chat log stays clean,
    # but we send the formatted version to the API.
    chat_history.append({"role": "user", "content": user_input})
    
    try:
        # Create a temporary messages list just for this request to include the formatting instruction
        request_messages = chat_history[:-1] + [{"role": "user", "content": formatted_user_input}]

        # Display a spinning animation while waiting for the model
        with console.status("[bold cyan]GPU is thinking...[/bold cyan]", spinner="dots"):
            response = client.chat.completions.create(
                model=MODEL_NAME,
                messages=request_messages,
                max_tokens=1024,
                temperature=0.2
            )
            bot_reply = response.choices[0].message.content
        
        # Print the AI's response inside a neat panel, rendering Markdown and Code with syntax highlighting
        console.print(Panel(Markdown(bot_reply, code_theme="monokai"), title="[bold purple]AI Assistant[/bold purple]", border_style="purple"))
        
        chat_history.append({"role": "assistant", "content": bot_reply})
        
    except Exception as e:
        console.print(f"\n[bold red]❌ Error generating response:[/bold red] {e}\n")