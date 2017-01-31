#include "GameObject.h"
#include "GameManager.h"

GameObject::GameObject(GameObjectType objType,
	glm::vec3 startPosition,
	glm::vec3 startDirection,
	float startVelocity,
	glm::vec3 initialScale,
	InputComponent* input,
	PhysicsComponent* physics,
	RenderComponent* render)
	: type(objType),
	direction(glm::normalize(startDirection)),
	velocity(startVelocity),
   orientAngle_(0),
   toggleMovement(false),
	input_(input),
	physics_(physics),
	render_(render) {

	// Set initial position and scale values
	setPosition(startPosition);
	setScale(initialScale);

   if (input_ != NULL) {
      input_->setGameObjectHolder(this);
   }

	if (render_ != NULL) {
		render_->setGameObjectHolder(this);
		boundBox = BoundingBox(render_->getShape()->getMin(), render_->getShape()->getMax());
	}
	else {

		// If no render component, set BoundingBox to min(0,0,0) -> max(0,0,0)
		boundBox = BoundingBox();
	}

	if (physics_ != NULL) {
		physics_->setGameObjectHolder(this);
		physics_->updateBoundingBox();
		physics_->initObjectPhysics();
	}
	else {
		// TODO(rgarmsen2295): Move all bounding box stuff to base physics component class
		boundBox.update(transform.getTransform());
	}
}

GameObject::~GameObject() {

}

glm::vec3& GameObject::getPosition() {
	return position_;
}

glm::vec3& GameObject::getScale() {
	return scale_;
}

void GameObject::setOrientAngle(float orientAngle) {
   orientAngle_ = orientAngle;
}

float GameObject::getOrientAngle() {
   return orientAngle_;
}

float GameObject::getYAxisRotation() {
	return yRotationAngle_;
}

void GameObject::setPosition(glm::vec3& newPosition) {
	position_ = newPosition;
	transform.setTranslation(position_);
}

void GameObject::setScale(glm::vec3& newScale) {
	scale_ = newScale;
	transform.setScale(scale_);
}

void GameObject::setYAxisRotation(float angle) {
	static glm::vec3 yAxis(0.0f, 1.0f, 0.0f);

	yRotationAngle_ = angle;
	transform.setRotate(angle, yAxis);
}


void GameObject::changeMaterial(std::shared_ptr<Material> newMaterial) {
	if (newMaterial != render_->getMaterial()) {
		render_->setMaterial(newMaterial);
	}
}

void GameObject::update(double deltaTime) {
	if (input_ != NULL) {
		input_->pollInput();
	}

	if (physics_ != NULL) {
		physics_->updatePhysics(deltaTime);
	}
}

void GameObject::draw(std::shared_ptr<MatrixStack> P, std::shared_ptr<MatrixStack> M, std::shared_ptr<MatrixStack> V) {
	if (render_ != NULL) {
		render_->draw(P, M, V);
	}
}