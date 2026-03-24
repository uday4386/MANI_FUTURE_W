# Samanyudu TV - Migration Guide to VPS, PostgreSQL, and Cloudflare R2

This guide outlines the complete process for migrating away from managed Supabase to a self-hosted, scalable, and extremely cost-effective architecture.

## Target Architecture

1.  **Hosting & Compute:** DigitalOcean Droplet
    *   **OS:** Ubuntu 24.04 LTS
    *   **Backend API:** Node.js (Express) or Python (FastAPI). We will build this to replace the automatic Supabase API.
    *   **Admin Panel:** React Web App (hosted via Nginx or Docker on the VPS).
    *   **Reverse Proxy / Web Server:** Nginx (to handle SSL/TLS via Let's Encrypt and route traffic).

2.  **Database:** PostgreSQL
    *   Hosted directly on the DigitalOcean Droplet (or a managed managed PostgreSQL service for easier backups/maintenance).
    *   We will migrate the schema and data from Supabase.

3.  **Storage:** Cloudflare R2
    *   S3-compatible bucket for all images, videos, and shorts.
    *   Extremely cheap storage and **zero egress (bandwidth) fees**.

4.  **Authentication:**
    *   We will need to replace Supabase Auth.
    *   **Options:** 
        *   Firebase Auth (Free for OTP/Phone, easy to integrate into Flutter and React).
        *   Custom JWT implementation built directly into our new Node.js backend.

## Phase 1: Setup Infrastructure (DigitalOcean & Cloudflare)

### Step 1: Provision DigitalOcean Droplet
1. Create a DigitalOcean account.
2. Spin up an Ubuntu server. (A CX22 or CPX21 is a great, cheap starting point).
3. Secure the server: Set up SSH keys, disable password login, configure UFW (Firewall) to only allow ports 22 (SSH), 80 (HTTP), and 443 (HTTPS).

### Step 2: Setup Cloudflare R2
1. Create a Cloudflare account.
2. Enable R2 Storage and create a new bucket (e.g., `samanyudu-media`).
3. Generate S3-compatible API credentials (Access Key ID and Secret Access Key).
4. Connect a custom domain to the bucket (e.g., `cdn.samanyudutv.com`) for fast delivery.

## Phase 2: Building the Backend API

Supabase gives you a magic API to talk to your database. Since we are leaving Supabase, we must build our own API for the mobile app and admin panel to communicate with.

1. **Initialize a Node.js project** directly in a new folder (e.g., `Backend_API`).
2. **Install dependencies:** `express`, `pg` (PostgreSQL client), `aws-sdk` (for Cloudflare R2), `cors`, `dotenv`.
3. **Re-create Endpoints:**
    *   `GET /api/news` -> Fetches news from PostgreSQL.
    *   `POST /api/news` -> Inserts news.
    *   `POST /api/upload` -> Takes an image/video from the client and uploads it to Cloudflare R2 using the S3 SDK, returning the URL.
    *   Implement identical endpoints for Users, Shorts, Categories, Likes, etc.

## Phase 3: Database Migration

1. **Export from Supabase:** Go to your Supabase dashboard and export your entire database schema and data as a `.sql` file.
2. **Install PostgreSQL on DigitalOcean:** `sudo apt install postgresql`.
3. **Import Data:** Run the `.sql` file against your new PostgreSQL instance.

## Phase 4: Mobile App & Admin Panel Adjustments

### In the Flutter App (`Mobile_App`):
1. **Remove Supabase:** Delete `supabase_flutter` from `pubspec.yaml` and remove initialization code from `main.dart`.
2. **Replace API Calls:** Every place we currently do `supabase.from('news').select()` we must replace with standard HTTP requests (e.g., `http.get('https://api.samanyudutv.com/news')`).
3. **Authentication:** Implement Firebase Auth or your own JWT logic for the Login/Signup screens.

### In the React Admin Panel (`Admin_Portal`):
1. Similarly, remove the Supabase JS client.
2. Update all data fetching to use standard `fetch()` or `axios` calls pointing to your new DigitalOcean API instance.
3. Handle file uploads by sending them to your Node.js backend to stream to Cloudflare R2.

## Next Steps to Begin
If you want to start this journey, we should tackle it one phase at a time to prevent breaking the currently working system. 

**Recommended First Step:** Let's build the **Node.js Backend API sandbox** alongside your current project to start mirroring the database structure.

