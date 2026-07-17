# 🕵️ Spy Game

A fun single-device multiplayer party game where players pass a phone around to secretly view words, with hidden spies among them!

## 🎮 Live Demo

Play now: [https://spy.rez.run](https://spy.rez.run)

## 📝 Description

Spy Game is a social deduction game built with HTML and JavaScript. Players take turns viewing a secret word on their phone, but some players are designated as spies who don't see the word. The goal is to figure out who the spies are!

## ✨ Features

- 🎯 **Dynamic Spy Assignment**: 1 spy per 5 players (1-5 players = 1 spy, 6-10 = 2 spies, etc.)
- 📱 **Mobile Responsive**: Optimized for iPhone and Android devices
- 🔄 **Smart Word Selection**: Randomly picks words and remembers used ones
- 🎨 **Beautiful UI**: Modern gradient design with smooth animations
- 🌐 **Pass & Play**: Players pass a single device around the circle

## 🎯 How to Play

1. Enter the number of players (4-12 recommended)
2. Click "Start Game"
3. Pass the phone in a circle
4. Each player clicks "See the word" to view their role:
   - **Regular players** see the secret word
   - **Spies** see "You are a spy! 🕵️"
5. Click "I got it" to hide and pass to the next player
6. After everyone has seen their role, click "Start a new round"

## 📂 Project Structure

```
spy-game/
├── game.html                   # Main game file (HTML, CSS, JavaScript)
├── words.txt                   # Word list for the game
├── deploy-to-aws.ps1           # AWS infrastructure setup script
├── deploy-files.ps1            # File deployment script for S3 + CloudFront
├── .env.example                # Example environment configuration
├── .gitignore                  # Git ignore rules
└── README.md                   # This file
```

## 🚀 Deployment

This game is deployed on AWS using:
- **S3**: For static file hosting
- **CloudFront**: For global CDN distribution with HTTPS
- **Origin Access Identity (OAI)**: For secure S3 access

### Deploy to AWS

1. **Configure Environment** (one-time):
   ```powershell
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env and set your AWS credentials:
   # AWS_PROFILE=your-aws-profile-name
   # AWS_REGION=ap-southeast-2
   # BUCKET_GUID=your-unique-guid-here
   ```

2. **Setup Infrastructure** (one-time):
   ```powershell
   .\deploy-to-aws.ps1
   ```

3. **Deploy Updates**:
   ```powershell
   .\deploy-files.ps1
   ```

The deployment script automatically:
- Uploads files to S3
- Invalidates CloudFront cache
- Makes changes live in 1-5 minutes

## 🎲 Word Categories

The game includes words from:
- Countries and capital cities
- Famous landmarks
- Famous people
- Australian landmarks
- Famous foods (international)
- Fruits
- Common objects (household, transport, celestial)

## 🛠️ Technologies Used

- HTML5
- CSS3 (with Flexbox and animations)
- Vanilla JavaScript
- AWS S3
- AWS CloudFront
- PowerShell (deployment scripts)

## 📱 Local Development

To run locally:

1. Clone the repository:
   ```bash
   git clone https://github.com/mehrbat/spy-game.git
   cd spy-game
   ```

2. Start a local web server:
   ```powershell
   py -m http.server 8000 --bind 0.0.0.0
   ```

3. Open in browser:
   ```
   http://localhost:8000/game.html
   ```

## 🔧 Configuration

### AWS Configuration

The project uses a `.env` file for AWS configuration (not committed to git):

```bash
AWS_PROFILE=your-aws-profile-name
AWS_REGION=ap-southeast-2
BUCKET_GUID=your-unique-guid-here
```

- `AWS_PROFILE`: Your AWS CLI profile name
- `AWS_REGION`: Target AWS region (default: ap-southeast-2 - Sydney)
- `BUCKET_GUID`: Unique identifier for S3 bucket (generate with `[guid]::NewGuid()` in PowerShell)

## 📄 License

MIT License - Feel free to use and modify!

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Add more words to `words.txt`
- Improve the UI/UX
- Add new game modes
- Fix bugs

## 🎉 Credits

Created with ❤️ for fun party games!
