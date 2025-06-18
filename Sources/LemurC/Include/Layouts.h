//
//  Layouts.h
//  LemurC
//
//  Created by Evgenij Lutz on 29.01.24.
//

#ifndef Lemur_Layouts_h
#define Lemur_Layouts_h

#include <simd/simd.h>


struct ColoredVertex {
    simd_float4 positionU;
    simd_float4 normalV;
    simd_float4 color;
};


struct SkinnedVertex {
    simd_float4 positionU;
    simd_float4 normalV;
    simd_int4 indices;
    simd_float4 weights;
};


struct MeshUniform {
    simd_float4x4 model;
};


struct WeightedMeshUniform {
    simd_float4x4 model0;
    simd_float4x4 model1;
};


struct SceneUniform {
    simd_float4x4 viewProjection;
    simd_float3 ambient;
};

#endif // Lemur_Layouts_h
