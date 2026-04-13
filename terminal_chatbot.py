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
custom_http_client = httpx.Client(verify=False)

# The client automatically uses OPENAI_BASE_URL and OPENAI_API_KEY from the devfile
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
**Type your message below.** Type `exit` or `quit` to end the session.
"""
console.print(Panel(Markdown(welcome_msg), title="🚀 OpenShift AI Terminal Chatbot", border_style="blue"))

# 2. INITIALIZE CHAT HISTORY
chat_history = [
    {"role": "system", "content": "You are a helpful, expert software engineering assistant. Keep your answers clear, accurate, and concise. Format code blocks using markdown."}
]

# 3. THE CHATBOT LOOP
while True:
    # Get user input with a colored prompt
    user_input = console.input("\n[bold green]You:[/bold green] ")
    
    if user_input.lower() in ['exit', 'quit']:
        console.print("[bold yellow]Ending session. Goodbye![/bold yellow]")
        break
        
    chat_history.append({"role": "user", "content": user_input})
    
    try:
        # Display a spinning animation while waiting for the model
        with console.status("[bold cyan]GPU is thinking...[/bold cyan]", spinner="dots"):
            response = client.chat.completions.create(
                model=MODEL_NAME,
                messages=chat_history,
                max_tokens=500,
                temperature=0.7
            )
            bot_reply = response.choices[0].message.content
        
        # Print the AI's response inside a neat panel, rendering any Markdown/Code
        console.print(Panel(Markdown(bot_reply), title="[bold purple]AI Assistant[/bold purple]", border_style="purple"))
        
        chat_history.append({"role": "assistant", "content": bot_reply})
        
    except Exception as e:
        console.print(f"\n[bold red]❌ Error generating response:[/bold red] {e}\n")