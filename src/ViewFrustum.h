#ifndef VIEW_FRUSTUM_H
#define VIEW_FRUSTUM_H

#include "GameObject.h"
#include <array>

class ViewFrustum {
public:
   ViewFrustum();

   ~ViewFrustum();

   void extractPlanes(glm::mat4 P, glm::mat4 V);

   bool cull(std::shared_ptr<GameObject> obj);

private:
   std::array<glm::vec4, 6> planes;
};

#endif
