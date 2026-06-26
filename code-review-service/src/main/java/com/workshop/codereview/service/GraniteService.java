package com.workshop.codereview.service;

import com.workshop.codereview.model.ReviewResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

@Service
public class GraniteService {

    private final HttpClient httpClient;

    @Value("${granite.api.base-url}")
    private String baseUrl;

    @Value("${granite.api.key}")
    private String apiKey;

    @Value("${granite.model.name}")
    private String modelName;

    public GraniteService(HttpClient httpClient) {
        this.httpClient = httpClient;
    }

    public ReviewResponse reviewCode(String code, String language) {
        String prompt = "Review the following " + language + " code for bugs, style issues, "
                + "and improvements. Be concise.\\n\\n```\\n" + code + "\\n```";

        String jsonPayload = """
                {
                    "model": "%s",
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are a senior code reviewer. Provide clear, actionable feedback."
                        },
                        {
                            "role": "user",
                            "content": "%s"
                        }
                    ],
                    "max_tokens": 512,
                    "temperature": 0.3
                }
                """.formatted(modelName, prompt.replace("\"", "\\\"").replace("\n", "\\n"));

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(baseUrl + "/completions"))
                    .header("Content-Type", "application/json")
                    .header("Authorization", "Bearer " + apiKey)
                    .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                return new ReviewResponse(
                        "Error: Model returned status " + response.statusCode() + ": " + response.body(),
                        modelName);
            }

            String reviewText = extractContent(response.body());
            return new ReviewResponse(reviewText, modelName);

        } catch (Exception e) {
            return new ReviewResponse("Error: " + e.getMessage(), modelName);
        }
    }

    private String extractContent(String json) {
        try {
            int textStart = json.indexOf("\"text\"");
            if (textStart == -1) {
                return "Error: Could not parse model response. Raw: " + json;
            }
            int colonPos = json.indexOf(":", textStart);
            int contentStart = json.indexOf("\"", colonPos + 1);
            int contentEnd = json.indexOf("\"", contentStart + 1);
            while (contentEnd > 0 && json.charAt(contentEnd - 1) == '\\') {
                contentEnd = json.indexOf("\"", contentEnd + 1);
            }
            return json.substring(contentStart + 1, contentEnd);
        } catch (Exception e) {
            return "Error parsing response: " + e.getMessage();
        }
    }
}
