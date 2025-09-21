import { 
  joinVoiceChannel, 
  type VoiceConnection,
  VoiceConnectionStatus,
  type VoiceReceiver,
  EndBehaviorType
} from '@discordjs/voice';
import type { Client, VoiceState, TextChannel, VoiceChannel, Guild } from 'discord.js';
import { AudioProcessor } from './speech-transcription';

const activeConnections = new Map<string, VoiceConnection>();

export function setupVoiceListener(client: Client) {
  console.log('Setting up voice channel listener...');
  
  // Listen for voice state updates (when users join/leave/mute/unmute)
  client.on('voiceStateUpdate', async (oldState: VoiceState, newState: VoiceState) => {
    const member = newState.member;
    if (!member || member.user.bot) return; // Ignore bots
    
    // User joined a voice channel
    if (!oldState.channelId && newState.channelId) {
      console.log(`${member.user.username} joined voice channel: ${newState.channel?.name}`);
      
      // Join the voice channel to listen for speech
      await joinVoiceChannelForListening(newState.channel as VoiceChannel, client);
    }
    
    // User left a voice channel
    if (oldState.channelId && !newState.channelId) {
      console.log(`${member.user.username} left voice channel: ${oldState.channel?.name}`);
      
      // Check if we should leave the channel (if no other users)
      await handleUserLeftChannel(oldState.channel as VoiceChannel);
    }
  });
}

async function joinVoiceChannelForListening(voiceChannel: VoiceChannel, client: Client) {
  if (!voiceChannel || !voiceChannel.guild) return;
  
  const guildId = voiceChannel.guild.id;
  
  // Check if we're already connected to this voice channel
  if (activeConnections.has(guildId)) {
    console.log(`Already connected to voice channel in guild ${guildId}`);
    return;
  }
  
  try {
    console.log(`Joining voice channel: ${voiceChannel.name}`);
    
    const connection = joinVoiceChannel({
      channelId: voiceChannel.id,
      guildId: voiceChannel.guild.id,
      adapterCreator: voiceChannel.guild.voiceAdapterCreator,
      selfDeaf: false, // Important: don't self-deafen to hear users
      selfMute: true,  // Mute ourselves since we're just listening
    });
    
    activeConnections.set(guildId, connection);
    
    connection.on(VoiceConnectionStatus.Ready, () => {
      console.log(`Voice connection ready in ${voiceChannel.name}`);
      setupSpeechDetection(connection, voiceChannel, client);
    });
    
    connection.on(VoiceConnectionStatus.Disconnected, () => {
      console.log(`Disconnected from ${voiceChannel.name}`);
      activeConnections.delete(guildId);
    });
    
    connection.on('error', (error) => {
      console.error(`Voice connection error in ${voiceChannel.name}:`, error);
      activeConnections.delete(guildId);
    });
    
  } catch (error) {
    console.error('Failed to join voice channel:', error);
  }
}

function setupSpeechDetection(connection: VoiceConnection, voiceChannel: VoiceChannel, client: Client) {
  console.log('Setting up speech detection and transcription...');
  
  // Get the voice receiver
  const receiver = connection.receiver;
  
  // Track users who are currently speaking to avoid spam
  const speakingUsers = new Set<string>();
  
  // Listen for users starting to speak
  receiver.speaking.on('start', (userId) => {
    if (speakingUsers.has(userId)) return; // Already detected this user speaking
    
    speakingUsers.add(userId);
    
    // Remove from set after a delay to allow detection again
    setTimeout(() => {
      speakingUsers.delete(userId);
    }, 2000); // 3 second cooldown per user
    
    // Get the user who started speaking
    const user = client.users.cache.get(userId);
    if (!user || user.bot) return;
    
    console.log(`Speech detected from: ${user.username}`);
    
    // Set up audio transcription for this user
    setupAudioTranscription(receiver, userId, user.username, voiceChannel.guild);
  });
}

function setupAudioTranscription(receiver: VoiceReceiver, userId: string, username: string, guild: Guild) {
  console.log(`Setting up transcription for ${username}`);
  const audioProcessor = new AudioProcessor()
  
  // Subscribe to the user's audio stream
  const audioStream = receiver.subscribe(userId, {
    end: {
      behavior: EndBehaviorType.AfterSilence,
      duration: 2000, // End after 1 second of silence
    },
  });
  
  // Create opus decoder to convert Opus to PCM
  const prism = require('prism-media');
  const opusDecoder = new prism.opus.Decoder({
    frameSize: 960,
    channels: 1, // Mono
    rate: 48000
  });
  
  // Collect PCM audio chunks after decoding
  const audioChunks: Buffer[] = [];
  
  // Pipe the audio stream through the Opus decoder
  audioStream.pipe(opusDecoder);
  
  // Collect decoded PCM data
  opusDecoder.on('data', (chunk: Buffer) => {
    audioChunks.push(chunk);
  });
  
  // Process audio when stream ends (after silence)
  opusDecoder.on('end', () => {
    console.log(`Audio stream ended for ${username}, processing ${audioChunks.length} PCM chunks`);
    
    if (audioChunks.length < 100) {
      console.log(`ignoring ${audioChunks.length}, too short.`)
      return
    }

    // Combine all audio chunks
    const combinedAudio = Buffer.concat(audioChunks);
    console.log(`Processing combined PCM audio: ${combinedAudio.length} bytes for ${username}`);
    
    // Process the audio directly with the transcription service
    audioProcessor.processAudioBuffer(combinedAudio, userId, username, (transcription: string) => {
      sendTranscriptionMessage(guild, username, transcription);
    });
  });
  
  // Handle errors
  opusDecoder.on('error', (error: Error) => {
    console.error(`Opus decoder error for ${username}:`, error);
  });
  
  audioStream.on('error', (error: Error) => {
    console.error(`Audio stream error for ${username}:`, error);
  });
}

async function sendTranscriptionMessage(guild: Guild, username: string, transcription: string) {
  try {
    // Find the general channel
    const generalChannel = guild.channels.cache.find(
      (channel) => channel.name === 'general' && channel.type === 0 // 0 = GUILD_TEXT
    ) as TextChannel;
    
    if (generalChannel) {
      await generalChannel.send(`🗣️ **${username}**: ${transcription}`);
      console.log(`Sent transcription for ${username}: ${transcription}`);
    } else {
      console.log('General channel not found');
    }
  } catch (error) {
    console.error('Failed to send transcription message:', error);
  }
}

async function handleUserLeftChannel(voiceChannel: VoiceChannel) {
  if (!voiceChannel || !voiceChannel.guild) return;
  
  // Check if there are still non-bot users in the channel
  const nonBotMembers = voiceChannel.members.filter(member => !member.user.bot);
  
  if (nonBotMembers.size === 0) {
    // No users left, disconnect from voice channel
    const guildId = voiceChannel.guild.id;
    const connection = activeConnections.get(guildId);
    
    if (connection) {
      console.log(`No users left in ${voiceChannel.name}, disconnecting...`);
      connection.destroy();
      activeConnections.delete(guildId);
    }
  }
}

export function disconnectFromAllVoiceChannels() {
  console.log('Disconnecting from all voice channels...');
  for (const [, connection] of activeConnections) {
    connection.destroy();
  }
  activeConnections.clear();
}