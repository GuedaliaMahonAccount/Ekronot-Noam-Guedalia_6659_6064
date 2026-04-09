# Project 09: 2D Basketball Shooting Game

## Project and Submitters Information
* **Course:** Nand2Tetris
* **Submitter 1:** Noam Hadad (ID: [Insert ID])
* **Submitter 2:** [Partner Name] (ID: [Insert Partner ID])

## Game Description
The 2D Basketball Shooting Game is an interactive graphical application built using the Jack programming language. The primary objective of the game is to skillfully control a player character across the bottom of the screen to shoot a basketball into a continuously moving hoop. The game challenges the user's timing and spatial coordination.

## Controls
The game is controlled using the standard keyboard inputs:
* **Left Arrow:** Move the player to the left.
* **Right Arrow:** Move the player to the right.
* **Spacebar:** Shoot the basketball towards the hoop.
* **Q:** Quit the game.

## File Architecture
The project is modularly designed and consists of the following core Jack files:

* `Main.jack`: Serves as the entry point of the application. It is responsible for initializing the game instance and starting the main execution loop, ultimately disposing of the game upon exit.
* `BasketballGame.jack`: Manages the overarching game state and orchestrates the interactions between the player, ball, and hoop. It contains the main game loop, processes user inputs, and handles the scoring logic.
* `Player.jack`: Represents the user-controlled character. It encapsulates the graphical rendering of the player, tracks its coordinates, and implements the horizontal movement mechanics.
* `Ball.jack`: Manages the properties and behaviors of the basketball. It handles the drawing, trajectory calculations, and positional updates of the ball as it is shot towards the hoop.

## Execution Instructions
To properly run and play the 2D Basketball Shooting Game, please follow these steps:
1. Ensure that all the standard Nand2Tetris Operating System (OS) `.vm` files are placed within the game folder.
2. Compile the entire directory using the provided `JackCompiler`.
3. Open the `VMEmulator` and load the project directory.
4. For optimal performance and smooth gameplay, ensure that the **Animation** setting is turned **Off** (set to "No animation").
5. Run the program and enjoy!