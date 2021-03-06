#include "GameManager.h"

GameManager& GameManager::instance() {
	static GameManager *instance = new GameManager();
	return *instance;
}

Camera& GameManager::getCamera() {
	return *currentCamera_;
}

void GameManager::setCamera(Camera* newCamera) {
	currentCamera_ = newCamera;
}

std::shared_ptr<GameObject> GameManager::getPlayer() {
   return currentPlayer_;
}

void GameManager::setPlayer(std::shared_ptr<GameObject> newPlayer) {
   currentPlayer_ = newPlayer;
}

ViewFrustum& GameManager::getViewFrustum() {
   return *currentViewFrustum_;
}

void GameManager::setViewFrustum(ViewFrustum* newViewFrustum) {
   currentViewFrustum_ = newViewFrustum;
}

GameWorld& GameManager::getGameWorld() {
	return *currentWorld_;
}

void GameManager::setGameWorld(GameWorld* newWorld) {
	currentWorld_ = newWorld;
}

void GameManager::printInfoToConsole(float currentFPS) {
	printf("Current FPS: %-10.2lf", currentFPS);
	std::cout << " Number of dynamic objects in world: " << currentWorld_->getNumDynamicGameObjects();
	std::cout << " Number of dynamic objects hit: " << currentWorld_->getNumBunniesHit() << '\r' <<  std::flush;
}

void GameManager::reportScore(float score) {
	score_ += score;
    std::cout << "Score: " << score_ << " (+" << score << ")" << std::endl;
}

void GameManager::setTime(float time) {
    time_ = time;
}

void GameManager::decreaseTime(float deltaTime) {
    time_ -= deltaTime;
	if(time_ <= 0.0) {
		gameOver_ = true;
	}
}

void GameManager::increaseTime(float deltaTime) {
    time_ += deltaTime;
}

void GameManager::setShadowMap(ShadowMap *shadowMap) {
    shadowMap_ = shadowMap;
}

ShadowMap* GameManager::getShadowMap() {
    return shadowMap_;
}

void GameManager::showScore() {
    if(gameOver_) {
        if(time_ <= 0.0) {
            std::cout << "YOU LOST!" << std::endl;
        } else {
            std::cout << "YOU WON!" << std::endl;
            std::cout << "Time left: " << time_ << std::endl;
            reportScore(time_ * 100);
        }
    }
	std::cout << "SCORE " << score_ << std::endl;
}

