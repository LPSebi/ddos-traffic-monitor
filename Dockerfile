# Use a lightweight Alpine base image
FROM alpine:3.18

# Install required dependencies
RUN apk add --no-cache \
    bash \
    figlet \
    tcpdump \
    vnstat \
    jq \
    curl

# Create working directory
WORKDIR /app

# Copy necessary files
COPY ddoswarningbandwidth.sh .
COPY libs/ ./libs/

# Make script executable
RUN chmod +x ddoswarningbandwidth.sh \
    && chmod +x libs/discord.sh

# Entrypoint configuration
ENTRYPOINT ["/bin/sh", "-c", "./ddoswarningbandwidth.sh \"$WEBHOOK\" \"$INTERFACE\" \"$MAX_SPEED\" \"$COUNT_PACKET\" \"$AVATAR\" \"$USERNAME\""]
