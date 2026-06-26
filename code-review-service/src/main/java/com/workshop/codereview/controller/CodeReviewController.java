package com.workshop.codereview.controller;

import com.workshop.codereview.model.ReviewRequest;
import com.workshop.codereview.model.ReviewResponse;
import com.workshop.codereview.service.GraniteService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class CodeReviewController {

    private final GraniteService graniteService;

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Code Review Service is running!");
    }

    @GetMapping("/review")
    public ResponseEntity<ReviewResponse> reviewCode(@RequestBody ReviewRequest request) {
        ReviewResponse response = graniteService.reviewCode(request.getCode(), request.getLanguage());
        return ResponseEntity.ok(response);
    }
}
