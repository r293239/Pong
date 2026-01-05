import SwiftUI

enum GameMode {
    case vsAI, twoPlayer
}

enum Difficulty {
    case easy, medium, hard
    
    var aiSpeed: CGFloat {
        switch self {
        case .easy: return 2
        case .medium: return 4
        case .hard: return 6
        }
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let pointsOnStar = 5
        
        var path = Path()
        let angle = Double.pi * 2 / Double(pointsOnStar * 2)
        let radius = min(rect.width, rect.height) / 2
        
        var currentAngle = -Double.pi / 2
        
        var firstPoint = true
        
        for i in 0..<(pointsOnStar * 2) {
            let length = i % 2 == 0 ? radius : radius / 2
            let x = center.x + CGFloat(cos(currentAngle) * length)
            let y = center.y + CGFloat(sin(currentAngle) * length)
            
            if firstPoint {
                path.move(to: CGPoint(x: x, y: y))
                firstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            currentAngle += angle
        }
        
        path.closeSubpath()
        return path
    }
}

struct ContentView: View {
    @State private var playerY: CGFloat = 0
    @State private var aiY: CGFloat = 0
    @State private var ballPosition = CGPoint.zero
    @State private var ballVelocity = CGVector(dx: 3, dy: 3)
    @State private var playerScore = 0
    @State private var aiScore = 0
    @State private var showCelebration = false
    @State private var gameOver = false
    @State private var showSpawnCircle = true
    @State private var spawnCircleScale: CGFloat = 0.1
    @State private var gameMode: GameMode = .vsAI
    @State private var difficulty: Difficulty = .medium
    @State private var powerUpPosition: CGPoint? = nil
    @State private var timeSinceBallSpawn: TimeInterval = 0
    
    // For paddle size powerup
    @State private var playerPaddleScale: CGFloat = 1.0
    @State private var aiPaddleScale: CGFloat = 1.0
    
    // Track last hitter: true = player, false = AI
    @State private var lastHitterIsPlayer: Bool = true
    
    let paddleWidth: CGFloat = 10
    let paddleHeight: CGFloat = 100
    let ballSize: CGFloat = 20
    let maxDY: CGFloat = 8
    let winningScore = 5
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Split court
                HStack(spacing: 0) {
                    Color.blue
                    Color.red
                }.edgesIgnoringSafeArea(.all)
                
                // Center line (purely visual)
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // Score
                Text("\(playerScore) : \(aiScore)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .position(x: geo.size.width / 2, y: 40)
                
                // Celebration
                if showCelebration {
                    Text("🎉 \(playerScore == winningScore ? "Blue" : "Red") Wins! 🎉")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                
                // Reset Button (center screen)
                if gameOver {
                    Button("Restart") {
                        resetGame()
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                
                // Paddles
                Rectangle()
                    .fill(Color.white)
                    .frame(width: paddleWidth, height: paddleHeight)
                    .scaleEffect(playerPaddleScale, anchor: .center)
                    .position(x: 30, y: geo.size.height / 2 + playerY)
                
                Rectangle()
                    .fill(Color.white)
                    .frame(width: paddleWidth, height: paddleHeight)
                    .scaleEffect(aiPaddleScale, anchor: .center)
                    .position(x: geo.size.width - 30, y: geo.size.height / 2 + aiY)
                
                // Ball
                if !showSpawnCircle {
                    Circle()
                        .fill(Color.white)
                        .frame(width: ballSize, height: ballSize)
                        .position(x: geo.size.width / 2 + ballPosition.x,
                                  y: geo.size.height / 2 + ballPosition.y)
                }
                
                // Spawn Animation Circle
                if showSpawnCircle {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .scaleEffect(spawnCircleScale)
                        .frame(width: 40, height: 40)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.4)) {
                                spawnCircleScale = 2.0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                showSpawnCircle = false
                            }
                        }
                }
                
                // Power-up Star
                if let powerUp = powerUpPosition {
                    StarShape()
                        .fill(Color.yellow)
                        .frame(width: 30, height: 30)
                        .position(x: geo.size.width / 2 + powerUp.x,
                                  y: geo.size.height / 2 + powerUp.y)
                }
                
                // Controls and border line above switches
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(height: 1)
                        .padding(.horizontal)
                    
                    Picker("Mode", selection: $gameMode) {
                        Text("VS AI").tag(GameMode.vsAI)
                        Text("2 Player").tag(GameMode.twoPlayer)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if gameMode == .vsAI {
                        Picker("Difficulty", selection: $difficulty) {
                            Text("Easy").tag(Difficulty.easy)
                            Text("Medium").tag(Difficulty.medium)
                            Text("Hard").tag(Difficulty.hard)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                }
                .foregroundColor(.white)
                .position(x: geo.size.width / 2, y: geo.size.height - 80)
            }
            .gesture(
                DragGesture().onChanged { value in
                    let center = geo.size.height / 2
                    if gameMode == .vsAI {
                        playerY = value.location.y - center
                    } else {
                        if value.startLocation.x < geo.size.width / 2 {
                            playerY = value.location.y - center
                        } else {
                            aiY = value.location.y - center
                        }
                    }
                }
            )
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                    guard !gameOver && !showSpawnCircle else { return }
                    
                    updateBall(in: geo.size)
                    if gameMode == .vsAI {
                        updateAI(with: geo.size)
                    }
                    
                    timeSinceBallSpawn += 0.016
                }
                
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    guard !gameOver && !showSpawnCircle else { return }
                    
                    if timeSinceBallSpawn >= 3 {
                        if Bool.random() && Int.random(in: 1...10) == 1 {
                            powerUpPosition = CGPoint(x: 0, y: 0)
                        }
                    }
                }
            }
        }
    }
    
    func updateBall(in size: CGSize) {
        var newX = ballPosition.x + ballVelocity.dx
        var newY = ballPosition.y + ballVelocity.dy
        
        // Bounce off top and bottom edges only
        if newY > size.height / 2 - ballSize / 2 {
            ballVelocity.dy *= -1
            newY = size.height / 2 - ballSize / 2
        }
        if newY < -size.height / 2 + ballSize / 2 {
            ballVelocity.dy *= -1
            newY = -size.height / 2 + ballSize / 2
        }
        
        ballVelocity.dy = max(-maxDY, min(maxDY, ballVelocity.dy))
        
        // Paddle collisions
        if newX < -size.width / 2 + 50,
           abs(ballPosition.y - playerY) < (paddleHeight / 2) * playerPaddleScale + ballSize / 2 {
            // Left paddle collision
            
            if ballVelocity.dx < 0 {
                ballVelocity.dx *= -1.1
                lastHitterIsPlayer = true
                
                // Adjust dy based on where ball hit paddle
                let offset = (ballPosition.y - playerY) / ((paddleHeight / 2) * playerPaddleScale)
                ballVelocity.dy += offset * 5
            }
            newX = -size.width / 2 + 50
        }
        
        if newX > size.width / 2 - 50,
           abs(ballPosition.y - aiY) < (paddleHeight / 2) * aiPaddleScale + ballSize / 2 {
            // Right paddle collision
            if ballVelocity.dx > 0 {
                ballVelocity.dx *= -1.1
                lastHitterIsPlayer = false
                
                // Adjust dy based on where ball hit paddle
                let offset = (ballPosition.y - aiY) / ((paddleHeight / 2) * aiPaddleScale)
                ballVelocity.dy += offset * 5
            }
            newX = size.width / 2 - 50
        }
        
        ballPosition = CGPoint(x: newX, y: newY)
        
        // Score check
        if newX < -size.width / 2 {
            // AI scores
            aiScore += 1
            checkGameOver()
            spawnBall()
        } else if newX > size.width / 2 {
            // Player scores
            playerScore += 1
            checkGameOver()
            spawnBall()
        }
        
        // Check powerup collision
        if let powerUp = powerUpPosition {
            let ballScreenPos = CGPoint(x: size.width / 2 + ballPosition.x, y: size.height / 2 + ballPosition.y)
            let powerUpScreenPos = CGPoint(x: size.width / 2 + powerUp.x, y: size.height / 2 + powerUp.y)
            
            let distance = hypot(ballScreenPos.x - powerUpScreenPos.x, ballScreenPos.y - powerUpScreenPos.y)
            if distance < (ballSize + 30) / 2 {
                activatePowerUp()
                powerUpPosition = nil
            }
        }
        
        // Gradually speed up ball
        let speedIncrease = 0.0005
        let currentSpeed = sqrt(ballVelocity.dx * ballVelocity.dx + ballVelocity.dy * ballVelocity.dy)
        if currentSpeed < 15 {
            let newSpeed = currentSpeed + CGFloat(speedIncrease)
            let angle = atan2(ballVelocity.dy, ballVelocity.dx)
            ballVelocity.dx = cos(angle) * newSpeed
            ballVelocity.dy = sin(angle) * newSpeed
        }
    }
    
    func spawnBall() {
        ballPosition = .zero
        ballVelocity = CGVector(dx: 3, dy: 3)
        timeSinceBallSpawn = 0
        showSpawnCircle = true
        spawnCircleScale = 0.1
        powerUpPosition = nil
    }
    
    func checkGameOver() {
        if playerScore >= winningScore || aiScore >= winningScore {
            gameOver = true
            showCelebration = true
        }
    }
    
    func updateAI(with size: CGSize) {
        // Smarter AI with prediction
        let predictionFactor: CGFloat
        switch difficulty {
        case .easy:
            predictionFactor = 0.1
        case .medium:
            predictionFactor = 0.6
        case .hard:
            predictionFactor = 1.0
        }
        
        var predictedY = aiY
        if ballVelocity.dx > 0 {
            let timeToReachAI = (size.width / 2 - 50 - ballPosition.x) / ballVelocity.dx
            predictedY = ballPosition.y + ballVelocity.dy * timeToReachAI * (1 + predictionFactor)
        }
        
        // Clamp prediction within screen bounds
        let maxY = size.height / 2 - paddleHeight / 2 * aiPaddleScale
        let minY = -maxY
        predictedY = min(max(predictedY, minY), maxY)
        
        // Move AI paddle smoothly towards predicted Y
        let speed = difficulty.aiSpeed
        let diff = predictedY - aiY
        
        if abs(diff) > speed {
            aiY += speed * (diff > 0 ? 1 : -1)
        } else {
            aiY = predictedY
        }
    }
    
    func activatePowerUp() {
        if lastHitterIsPlayer {
            withAnimation(.easeInOut(duration: 5)) {
                playerPaddleScale = 1.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    playerPaddleScale = 1.0
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 5)) {
                aiPaddleScale = 1.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    aiPaddleScale = 1.0
                }
            }
        }
    }
    
    func resetGame() {
        playerScore = 0
        aiScore = 0
        gameOver = false
        showCelebration = false
        ballPosition = .zero
        ballVelocity = CGVector(dx: 3, dy: 3)
        playerY = 0
        aiY = 0
        timeSinceBallSpawn = 0
        powerUpPosition = nil
        showSpawnCircle = true
        spawnCircleScale = 0.1
        playerPaddleScale = 1.0
        aiPaddleScale = 1.0
        lastHitterIsPlayer = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


