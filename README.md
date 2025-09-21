# Wyrmbot

A Discord bot that transcribes voice channel conversations using OpenAI Whisper API.

## Features

- 🎙️ **Voice Transcription**: Automatically transcribes speech in Discord voice channels
- 🤖 **Smart Detection**: Only processes meaningful audio (filters out short sounds)
- 🌍 **Multi-language**: Auto-detects English and German
- ☁️ **Cloud Deployment**: Fully automated AWS EC2 deployment with Terraform
- 🔄 **Spot Instance Ready**: Survives EC2 spot instance restarts

## Setup

### Prerequisites

- Node.js (LTS version)
- Discord Bot Token & Application ID
- OpenAI API Key
- AWS Account (for cloud deployment)

### Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/Eik-S/wyrmbot.git
   cd wyrmbot
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create `.env` file:
   ```env
   DISCORD_TOKEN=your_discord_bot_token
   DISCORD_CLIENT_ID=your_discord_app_id
   SECRET_OPENAI_API_KEY=your_openai_api_key
   ```

4. Run locally:
   ```bash
   npm start
   ```

### Cloud Deployment

1. Set up AWS credentials and create SSH key pair named `wyrmbot-key`

2. Navigate to infrastructure directory:
   ```bash
   cd _infrastructure
   ```

3. Initialize and apply Terraform:
   ```bash
   terraform init
   terraform apply
   ```

The bot will automatically:
- Clone the latest code from GitHub
- Set up the environment with your secrets
- Start the service automatically
- Restart on spot instance interruptions

## Commands

- `/ping` - Test command that replies with "Pong!"

## Architecture

```
src/
├── index.ts                    # Main bot entry point
└── voice/
    ├── voice-listener.ts       # Voice channel event handling
    └── speech-transcription.ts # Audio processing and Whisper API
```

## How It Works

1. Bot joins voice channels when users are present
2. Listens for speech detection events
3. Captures and processes audio streams
4. Converts Opus audio to PCM format
5. Sends audio to OpenAI Whisper for transcription
6. Posts transcription to the #general channel
7. Automatically leaves empty voice channels

## License

ISC