
#define SCENE_INVALID_INDEX (-1)
#define SCENE_MAX_BUFFERS (16)
#define SCENE_MAX_IMAGES (16)
#define SCENE_MAX_MATERIALS (16)
#define SCENE_MAX_PIPELINES (16)
#define SCENE_MAX_PRIMITIVES (16)   // aka submesh
#define SCENE_MAX_MESHES (16)
#define SCENE_MAX_NODES (16)

// statically allocated buffers for file downloads
#define SFETCH_NUM_CHANNELS (1)
#define SFETCH_NUM_LANES (4)
#define MAX_FILE_SIZE (1024*1024)
uint8_t sfetch_buffers[SFETCH_NUM_CHANNELS][SFETCH_NUM_LANES][MAX_FILE_SIZE];

// per-material texture indices into scene.images for metallic material
typedef struct {
    int base_color;
    int metallic_roughness;
    int normal;
    int occlusion;
    int emissive;
} metallic_images_t;

// per-material texture indices into scene.images for specular material
typedef struct {
    int diffuse;
    int specular_glossiness;
    int normal;
    int occlusion;
    int emissive;
} specular_images_t;

// fragment-shader-params and textures for metallic material
typedef struct {
    int fs_params;
    metallic_images_t images;
} metallic_material_t;

// fragment-shader-params and textures for specular material
typedef struct {
    int fs_params;
    specular_images_t images;
} specular_material_t;

// ...and everything grouped into a material struct
typedef struct {
    bool is_metallic;
    union {
        metallic_material_t metallic;
        specular_material_t specular;
    };
} material_t;

// helper struct to map sokol-gfx buffer bindslots to scene.buffers indices
typedef struct {
    int num;
    int buffer[SG_MAX_VERTEXBUFFER_BINDSLOTS];
} vertex_buffer_mapping_t;

// a 'primitive' (aka submesh) contains everything needed to issue a draw call
typedef struct {
    int pipeline;           // index into scene.pipelines array
    int material;           // index into scene.materials array
    vertex_buffer_mapping_t vertex_buffers; // indices into bufferview array by vbuf bind slot
    int index_buffer;       // index into bufferview array for index buffer, or SCENE_INVALID_INDEX
    int base_element;       // index of first index or vertex to draw
    int num_elements;       // number of vertices or indices to draw
} primitive_t;

// a mesh is just a group of primitives (aka submeshes)
typedef struct {
    int first_primitive;    // index into scene.primitives
    int num_primitives;
} mesh_t;

// a node associates a transform with an mesh,
// currently, the transform matrices are 'baked' upfront into world space
typedef struct {
    int mesh;           // index into scene.meshes
    mat44_t transform;
} node_t;

typedef struct {
    sg_image img;
    sg_view tex_view;
    sg_sampler smp;
} image_t;

// the complete scene
typedef struct {
    int num_buffers;
    int num_images;
    int num_pipelines;
    int num_materials;
    int num_primitives; // aka 'submeshes'
    int num_meshes;
    int num_nodes;
    sg_buffer buffers[SCENE_MAX_BUFFERS];
    image_t images[SCENE_MAX_IMAGES];
    sg_pipeline pipelines[SCENE_MAX_PIPELINES];
    material_t materials[SCENE_MAX_MATERIALS];
    primitive_t primitives[SCENE_MAX_PRIMITIVES];
    mesh_t meshes[SCENE_MAX_MESHES];
    node_t nodes[SCENE_MAX_NODES];
} scene_t;

// resource creation helper params, these are stored until the
// async-loaded resources (buffers and images) have been loaded
typedef struct {
    sg_buffer_usage usage;
    int offset;
    int size;
    int gltf_buffer_index;
} buffer_creation_params_t;

typedef struct {
    sg_filter min_filter;
    sg_filter mag_filter;
    sg_filter mipmap_filter;
    sg_wrap wrap_s;
    sg_wrap wrap_t;
    int gltf_image_index;
} image_sampler_creation_params_t;

// pipeline cache helper struct to avoid duplicate pipeline-state-objects
typedef struct {
    sg_vertex_layout_state layout;
    sg_primitive_type prim_type;
    sg_index_type index_type;
    bool alpha;
} pipeline_cache_params_t;

// the top-level application state struct
static struct {
    bool failed;
    struct {
        sg_pass_action ok;
        sg_pass_action failed;
    } pass_actions;
    struct {
        sg_shader metallic;
        sg_shader specular;
    } shaders;
    sg_sampler smp;
    scene_t scene;
    camera_t camera;
    cgltf_light_params_t point_light;     // code-generated from shader
    mat44_t root_transform;
    float rx, ry;
    struct {
        buffer_creation_params_t buffers[SCENE_MAX_BUFFERS];
        image_sampler_creation_params_t images[SCENE_MAX_IMAGES];
    } creation_params;
    struct {
        pipeline_cache_params_t items[SCENE_MAX_PIPELINES];
    } pip_cache;
    struct {
        sg_view white;
        sg_view normal;
        sg_view black;
        sg_sampler smp;
    } placeholders;
} state;