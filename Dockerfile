# ==========================================
# DOCKERFILE - Simple Recipe to Package Our App
# ==========================================
# Think of this like a cooking recipe that tells Docker:
# 1. What ingredients (base software) we need
# 2. What steps to follow to prepare our app
# 3. How to serve it (run it)


# STEP 1: Choose the base "operating system" for our app
# This is like choosing the kitchen where we'll cook
# We're using Node.js version 18 on a lightweight Linux system called Alpine
FROM node:18-alpine


# STEP 2: Create a folder inside the container to put our app
# Think of this as preparing a clean workspace
WORKDIR /app


# STEP 3: Copy the "shopping list" (package.json)
# This file tells us what libraries/tools our app needs
COPY package*.json ./


# STEP 4: Install all the libraries our app needs
# Like buying all ingredients from the shopping list
RUN npm install --production


# STEP 5: Copy our actual application code into the container
# This includes:
#   - server.js (the main program that runs the backend)
#   - public folder (contains HTML, CSS, JavaScript for the website)
COPY server.js ./
COPY public ./public


# STEP 6: Tell Docker which "door" (port) to open
# Port 3000 is where people can access our website
# Like opening the front door of a restaurant
EXPOSE 3000


# STEP 7: Set up the environment
# This tells the app to run in "production mode" (optimized for real use)
ENV NODE_ENV=production


# STEP 8: Start our application!
# This command runs our server.js file using Node.js
# Like turning on the oven and starting to cook
CMD ["node", "server.js"]


# ==========================================
# HOW TO USE THIS DOCKERFILE:
# ==========================================
# 1. Build the image (create the package):
#    docker build -t dailytask_web .
#
# 2. Run the container (start the app):
#    docker run -p 3000:3000 dailytask_web
#
# 3. Open in browser:
#    http://localhost:3000
# ==========================================
