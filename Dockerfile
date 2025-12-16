# Step 1: Use Nginx web server
FROM nginx:alpine

# Step 2: Copy all project files to Nginx folder
COPY . /usr/share/nginx/html

# Step 3: Expose port 80
EXPOSE 80
