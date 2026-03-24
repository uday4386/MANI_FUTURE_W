# Production deployment for samanyudutv.in

## 1) Cloudflare DNS
- `A` `@` -> `64.227.166.123` (Proxied)
- `A` `www` -> `64.227.166.123` (Proxied)
- `A` `admin` -> `64.227.166.123` (Proxied)
- `A` `api` -> `64.227.166.123` (Proxied)
- `CNAME` `media` -> your R2 custom-domain target (Proxied)
- SSL mode: `Full (strict)`

## 2) Server app paths
- Project root: `/var/www/samanyudu-tv`
- Admin build served from: `/var/www/samanyudu-tv/dist`
- Public web app served from: `/var/www/samanyudu-tv/public_web_app`
- Backend API process from: `/var/www/samanyudu-tv/backend_api`

## 3) Backend env
```bash
cd /var/www/samanyudu-tv/backend_api
cp .env.production.example .env
# Edit .env with real production DB + secret values
```

## 4) Install and start backend
```bash
cd /var/www/samanyudu-tv/backend_api
npm install
pm2 start "npm start" --name samanyudu-api
pm2 save
pm2 startup
```

## 5) Build admin
```bash
cd /var/www/samanyudu-tv
npm install
npm run build
```

## 6) Nginx
```bash
sudo cp /var/www/samanyudu-tv/nginx_samanyudutv.in.conf /etc/nginx/sites-available/samanyudutv.in.conf
sudo ln -sf /etc/nginx/sites-available/samanyudutv.in.conf /etc/nginx/sites-enabled/samanyudutv.in.conf
sudo nginx -t
sudo systemctl reload nginx
```

## 7) Smoke tests
```bash
curl -I https://api.samanyudutv.in/api/health
curl -I https://admin.samanyudutv.in
curl -I https://samanyudutv.in
```

## 8) Data migration (from old local DB)
```powershell
pg_dump -h localhost -U postgres -d samanyudu -Fc -f samanyudu.dump
```

```bash
pg_restore -h <PROD_DB_HOST> -U <PROD_DB_USER> -d <PROD_DB_NAME> --clean --if-exists /path/to/samanyudu.dump
```
