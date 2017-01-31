#ifndef _SHAPE_H_
#define _SHAPE_H_

#include <cfloat>
#include <memory>
#include <string>
#include <vector>

#include "glm/glm.hpp"
#include "glm/vec4.hpp"
#include "glm/mat4x4.hpp"
#include "glm/gtc/matrix_transform.hpp"

class Program;

class Shape
{
public:
	Shape();
	virtual ~Shape();
	void loadMesh(const std::string &meshName);
	void calculateNormals();
	void init();
	void resize();
	void draw(const std::shared_ptr<Program> prog) const;
	glm::vec3& getMin();
	glm::vec3& getMax();
	
private:
	std::vector<unsigned int> eleBuf;
	std::vector<float> posBuf;
	std::vector<float> norBuf;
	std::vector<float> texBuf;
	unsigned eleBufID;
	unsigned posBufID;
	unsigned norBufID;
	unsigned texBufID;
	unsigned vaoID;

	glm::vec3 min;
	glm::vec3 max;

	void findAndSetMinAndMax();
};

#endif