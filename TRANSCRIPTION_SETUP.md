# OpenAI Whisper API Integration Guide

Your Discord bot now has the basic infrastructure for speech transcription! This guide will help you integrate OpenAI's Whisper API for real-time speech-to-text functionality supporting English and German.

## Why OpenAI Whisper?

- ✅ **Excellent multilingual support** - Handles English and German seamlessly
- ✅ **High accuracy** - State-of-the-art speech recognition
- ✅ **Easy integration** - Simple REST API
- ✅ **Auto language detection** - No need to specify language beforehand
- ✅ **Cost-effective** - Pay per use model

## Setup Instructions

### 1. Install OpenAI Package

```bash
npm install openai
```

### 2. Get Your OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com)
2. Sign up or log in to your account
3. Navigate to **API Keys** section
4. Click **Create new secret key**
5. Copy your API key (starts with `sk-...`)

### 3. Set Up Environment Variables

Create a `.env` file in your project root:

```bash
# Create .env file
touch .env
```

Add your OpenAI API key to the `.env` file:

```env
OPENAI_API_KEY=your_api_key_here
```

Install dotenv to load environment variables:

```bash
npm install dotenv
```

### 4. Update Your Code

Replace the placeholder `transcribeAudio` method in `src/voice/speech-transcription.ts`:

```typescript
import OpenAI from 'openai';
import * as fs from 'fs';
import * as path from 'path';

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

class SpeechTranscriptionService {
  private options: SpeechToTextOptions;

  constructor(options: SpeechToTextOptions = { language: 'auto', sampleRate: 48000 }) {
    this.options = options;
  }

  async transcribeAudio(audioBuffer: Buffer): Promise<string | null> {
    try {
      // Save audio buffer to temporary file (Whisper API requires file input)
      const tempFilePath = path.join(__dirname, '../../temp', `audio_${Date.now()}.wav`);
      
      // Ensure temp directory exists
      const tempDir = path.dirname(tempFilePath);
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }
      
      // Write audio buffer to WAV file
      fs.writeFileSync(tempFilePath, audioBuffer);
      
      // Transcribe using OpenAI Whisper
      const transcription = await openai.audio.transcriptions.create({
        file: fs.createReadStream(tempFilePath),
        model: 'whisper-1',
        language: undefined, // Auto-detect between en/de
        response_format: 'text',
      });
      
      // Clean up temporary file
      fs.unlinkSync(tempFilePath);
      
      return transcription || null;
    } catch (error) {
      console.error('Whisper transcription error:', error);
      return null;
    }
  }
}
```

### 5. Update Your Main Bot File

Add environment variable loading to the top of `src/index.ts`:

```typescript
import 'dotenv/config'; // Add this at the very top
import { Client, Events, GatewayIntentBits, Message, REST, Routes } from 'discord.js';
// ... rest of your imports
```

## Audio Format Considerations

Discord provides audio in Opus format, but Whisper expects WAV/MP3/other formats. The current implementation saves the processed PCM audio as WAV files temporarily.

### Alternative: Direct Buffer Processing

For better performance, you could convert the audio buffer to a supported format in memory, but file-based approach is simpler and more reliable.

## Cost Considerations

- OpenAI Whisper API costs $0.006 per minute of audio
- For active voice chat, consider implementing rate limiting
- The current implementation processes speech segments (not continuous audio)

## Testing

Once you've completed the setup:

1. Join a voice channel in your Discord server
2. Start speaking in English or German  
3. Check the general channel for transcriptions like: "🗣️ **YourName**: Hello, this is a test"

## Troubleshooting

**Common Issues:**

- **API Key errors**: Make sure your `.env` file is in the project root and the API key is correct
- **File permission errors**: Ensure the bot can create/delete files in the temp directory
- **Audio quality**: Poor audio quality may result in inaccurate transcriptions
- **Rate limits**: OpenAI has rate limits - implement proper error handling

**Debug Tips:**

- Check console logs for transcription errors
- Verify audio buffer sizes are reasonable (not too small/large)
- Test with clear, slow speech first

## Security Notes

- Never commit your `.env` file to version control
- Add `.env` to your `.gitignore` file
- Consider rotating API keys periodically