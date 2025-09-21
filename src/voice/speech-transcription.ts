import OpenAI from 'openai';
import path from 'node:path';
import * as fs from 'node:fs'

// Mock speech-to-text service - replace with actual service
interface SpeechToTextOptions {
  language: 'en-US' | 'de-DE' | 'auto';
  sampleRate: number;
}

class SpeechTranscriptionService {
  private options: SpeechToTextOptions;
  private openai;

  constructor(options: SpeechToTextOptions = { language: 'auto', sampleRate: 48000 }) {
    this.options = options;
    this.openai = new OpenAI({
      apiKey: process.env.SECRET_OPENAI_API_KEY,
    });
  }

  async transcribeAudio(audioBuffer: Buffer): Promise<string | null> {
    try {
      console.log(`Processing audio buffer of ${audioBuffer.length} bytes for transcription`);
      
      // Check minimum audio length (48kHz * 1 channel * 2 bytes * 0.1 seconds = ~9,600 bytes minimum)
      const minAudioLength = 48000 * 1 * 2 * 0.1; // 0.1 seconds minimum for mono
      if (audioBuffer.length < minAudioLength) {
        console.log(`Audio too short: ${audioBuffer.length} bytes (minimum: ${minAudioLength})`);
        return null;
      }
      
      // Save audio buffer to temporary file (Whisper API requires file input)
      const tempFilePath = path.join(__dirname, '../../temp', `audio_${Date.now()}.wav`);
      
      // Ensure temp and debug directories exist
      const tempDir = path.dirname(tempFilePath);
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }
      
      // Create WAV file with proper headers (mono)
      const wavBuffer = this.createWavBuffer(audioBuffer, 48000, 1); // 48kHz, mono
      fs.writeFileSync(tempFilePath, wavBuffer);
      
      // Check if the WAV file was created successfully
      const fileStats = fs.statSync(tempFilePath);
      console.log(`Created WAV file: ${fileStats.size} bytes (audio duration: ~${(audioBuffer.length / (48000 * 1 * 2)).toFixed(2)} seconds)`);
      
      const transcription = await this.openai.audio.transcriptions.create({
        file: fs.createReadStream(tempFilePath),
        model: 'whisper-1',
        language: undefined, // Auto-detect between en/de
        response_format: 'text',
      });
      

      // Clean up temporary file (but keep debug file)
      fs.unlinkSync(tempFilePath);
      
      console.log(`Transcription result: "${transcription}"`);
      return transcription || null;
    } catch (error) {
      console.error('Whisper transcription error:', error);
      return null;
    }
  }

  createWavBuffer(pcmBuffer: Buffer, sampleRate: number, channels: number): Buffer {
    const dataLength = pcmBuffer.length;
    const headerLength = 44;
    const totalLength = headerLength + dataLength;
    
    const wavBuffer = Buffer.alloc(totalLength);
    
    // WAV header
    wavBuffer.write('RIFF', 0);
    wavBuffer.writeUInt32LE(totalLength - 8, 4);
    wavBuffer.write('WAVE', 8);
    wavBuffer.write('fmt ', 12);
    wavBuffer.writeUInt32LE(16, 16); // PCM format chunk size
    wavBuffer.writeUInt16LE(1, 20);  // PCM format
    wavBuffer.writeUInt16LE(channels, 22);
    wavBuffer.writeUInt32LE(sampleRate, 24);
    wavBuffer.writeUInt32LE(sampleRate * channels * 2, 28); // Byte rate
    wavBuffer.writeUInt16LE(channels * 2, 32); // Block align
    wavBuffer.writeUInt16LE(16, 34); // Bits per sample
    wavBuffer.write('data', 36);
    wavBuffer.writeUInt32LE(dataLength, 40);
    
    // Copy PCM data
    pcmBuffer.copy(wavBuffer, headerLength);
    
    return wavBuffer;
  }
}

export class AudioProcessor {
  private transcriptionService: SpeechTranscriptionService;

  constructor() {
    this.transcriptionService = new SpeechTranscriptionService({
      language: 'auto', // Auto-detect between English and German
      sampleRate: 48000
    });
  }

  // New simplified method to process audio buffer directly
  async processAudioBuffer(audioBuffer: Buffer, _userId: string, username: string, onTranscription: (text: string) => void) {
    console.log(`Processing audio buffer for ${username}: ${audioBuffer.length} bytes`);
    
    try {
      // Directly transcribe the audio buffer
      const transcription = await this.transcriptionService.transcribeAudio(audioBuffer);
      
      if (transcription?.trim()) {
        onTranscription(transcription);
      }
    } catch (error) {
      console.error(`Error processing audio for ${username}:`, error);
    }
  }
}