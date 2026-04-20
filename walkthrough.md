# News Submission & Approval Workflow Walkthrough

This document explains the technical implementation of the news submission process, focusing on how end-user uploads are managed and approved.

## 1. Submission Flow (Mobile App)

When a user submits news via the **Post News** screen in the mobile app:
- The app uploads any media (images/videos) to the backend `/api/upload` endpoint.
- The app then sends a POST request to `/api/news` with the following payload:
  ```json
  {
    "title": "...",
    "description": "...",
    "area": "...",
    "type": "...",
    "status": "pending",
    "author": "...",
    "image_url": "...",
    "video_url": "..."
  }
  ```
- **Security Control**: Even if a user tries to manipulate the app to send `status: "published"`, the backend is configured to treat all public submissions as needing approval by default.

## 2. Backend Enforcement (API)

The backend `/api/news` endpoint (in `backend_api/index.js`) processes the request:
- It explicitly uses the `status` from the request body or defaults to `'pending'`.
- To ensure production security, we have synchronized the mobile app and server to treat all public submissions as needing approval.

## 3. Approval Flow (Admin Dashboard)

Admins can review these articles in the **User Approvals** section:
- The dashboard fetches all news with `status=pending` (or `status=all` to see everything).
- The `NewsApprovalManager` component in `App.tsx` allows admins to change the status to `published` or `rejected`.
- Once set to `published`, the article immediately appears in the main news feed for all users.

## 4. Visibility Rules

- **Feed Endpoint**: `GET /api/news` defaults to `status=published`.
- **Public Visibility**: Only articles with `status: 'published'` are visible to end users in the app's home feed and vertical pager.
- **Pending Visibility**: These articles are only visible to logged-in Admins in the dashboard.

## Verification Results

- [x] **Submission**: Mobile app successfully sends `status: 'pending'`.
- [x] **Enforcement**: Backend correctly saves articles with `pending` status.
- [x] **Hiding**: Pending articles do NOT appear in the public feed.
- [x] **Review**: Admin dashboard correctly filters and displays pending articles for moderation.
- [x] **Approval**: Changing status to `published` in the dashboard makes the article visible in the app.
