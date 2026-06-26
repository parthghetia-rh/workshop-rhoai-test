import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

public class WorkingJavaChatAgent {
    private static final String BASE_URL = System.getenv().getOrDefault("OPENAI_BASE_URL", "http://localhost:8080");
    private static final String API_KEY = System.getenv().getOrDefault("OPENAI_API_KEY", "dummy-workshop-key");
    private static final String API_URL = BASE_URL + "/chat/completions";

    public static void main(String[] args) {
        String prompt = "Write a short haiku about coding in Java.";

        String jsonPayload = """
            {
                "model": "granite-8b-code-instruct",
                "messages": [
                    {
                        "role": "user",
                        "content": "%s"
                    }
                ],
                "max_tokens": 150
            }
            """.formatted(prompt);

        try {
            TrustManager[] trustAllCerts = new TrustManager[]{
                new X509TrustManager() {
                    public X509Certificate[] getAcceptedIssuers() { return null; }
                    public void checkClientTrusted(X509Certificate[] certs, String authType) {}
                    public void checkServerTrusted(X509Certificate[] certs, String authType) {}
                }
            };

            SSLContext sslContext = SSLContext.getInstance("TLS");
            sslContext.init(null, trustAllCerts, new SecureRandom());

            HttpClient client = HttpClient.newBuilder()
                    .sslContext(sslContext)
                    .build();

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(API_URL))
                    .header("Content-Type", "application/json")
                    .header("Authorization", "Bearer " + API_KEY)
                    .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
                    .build();

            System.out.println("Sending request to Granite model...");
            System.out.println("Endpoint: " + API_URL);

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            System.out.println("\n--- AI Response ---");
            System.out.println("Status Code: " + response.statusCode());
            System.out.println("Raw Body: \n" + response.body());

        } catch (Exception e) {
            System.out.println("Connection Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
