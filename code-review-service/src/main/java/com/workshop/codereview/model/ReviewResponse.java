package com.workshop.codereview.model;

public class ReviewResponse {

    private String review;
    private String model;

    public ReviewResponse() {}

    public ReviewResponse(String review, String model) {
        this.review = review;
        this.model = model;
    }

    public String getReview() { return review; }
    public void setReview(String review) { this.review = review; }

    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }
}
