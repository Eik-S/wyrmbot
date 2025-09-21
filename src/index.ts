import { Client, Events, GatewayIntentBits, REST, Routes } from 'discord.js';
import { setupVoiceListener } from './voice/voice-listener';

async function main() {
  if (process.env.NODE_ENV === 'dev') {
    await import('dotenv').then((dotenv) => {
      dotenv.config()
    })
  }
  await registerCommands()
  await startBot()
}

async function registerCommands() {
  const CLIENT_ID = process.env.DISCORD_CLIENT_ID
  const TOKEN = process.env.DISCORD_TOKEN
  if (!CLIENT_ID || !TOKEN) {
    console.error('DISCORD_TOKEN or DISCORD_CLIENT_ID env variable missing')
    return
  }
  const commands = [
    {
      name: 'ping',
      description: 'Replies with Pong!',
    },
  ];

  const rest = new REST({ version: '10' }).setToken(TOKEN);

  try {
    console.log('Started refreshing application (/) commands.');

    await rest.put(Routes.applicationCommands(CLIENT_ID), { body: commands });

    console.log('Successfully reloaded application (/) commands.');
  } catch (error) {
    console.error(error);
  }
}

async function startBot() {
  const TOKEN = process.env.DISCORD_TOKEN
  if (!TOKEN) {
    console.error('DISCORD_TOKEN env variable missing')
    return
  }

  const client = new Client({ 
    intents: [
      GatewayIntentBits.Guilds, 
      GatewayIntentBits.GuildMessages,
      GatewayIntentBits.GuildVoiceStates
    ] 
  });

  client.on(Events.ClientReady, readyClient => {
    console.log(`Logged in as ${readyClient.user.tag}!`);
    setupVoiceListener(readyClient);
  });

  client.on(Events.InteractionCreate, async interaction => {
    if (!interaction.isChatInputCommand()) return;

    if (interaction.commandName === 'ping') {
      await interaction.reply('Pong!');
    }
  });

  client.login(TOKEN);
}

main()

