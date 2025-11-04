using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;

public class HashVisualization : MonoBehaviour
{
    static int hashesId = Shader.PropertyToID("_Hashes");
    static int configId = Shader.PropertyToID("_Config");

    [SerializeField] Mesh instanceMesh;
    [SerializeField] Material material;
    [SerializeField, Range(1, 512)] int resolution = 16;
    [SerializeField] int seed = 0;

    NativeArray<uint> hashes;
    ComputeBuffer hashesBuffer;
    MaterialPropertyBlock propertyBlock;
    Material materialInstance;

    int prevResolution;
    int prevSeed;

    [BurstCompile(FloatPrecision.Standard, FloatMode.Fast, CompileSynchronously = true)]
    struct HashJob : IJobFor
    {
        [WriteOnly] public NativeArray<uint> hashes;
        public int resolution;
        public float invResolution;
        public int seed;

        public void Execute(int i)
        {
            int v = (int)math.floor(invResolution * i + 0.00001f);
            int u = i - resolution * v - resolution / 2;
            v -= resolution / 2;

            var h = SmallXXHash.Seed(seed).Eat(u).Eat(v);
            hashes[i] = h;
        }
    }

    void OnEnable()
    {
        materialInstance = new Material(material);
        Initialize();
        prevResolution = resolution;
        prevSeed = seed;
    }

    void OnDestroy()
    {
        if (hashes.IsCreated)
            hashes.Dispose();

        if (hashesBuffer != null)
        {
            hashesBuffer.Release();
            hashesBuffer = null;
        }

        if (materialInstance != null)
            Destroy(materialInstance);
    }

    void Initialize()
    {
        int length = resolution * resolution;

        if (hashes.IsCreated)
            hashes.Dispose();

        if (hashesBuffer != null)
        {
            hashesBuffer.Release();
            hashesBuffer = null;
        }

        hashes = new NativeArray<uint>(length, Allocator.Persistent);
        hashesBuffer = new ComputeBuffer(length, sizeof(uint));

        var job = new HashJob
        {
            hashes = hashes,
            resolution = resolution,
            invResolution = 1f / resolution,
            seed = seed
        };
        job.ScheduleParallel(hashes.Length, math.max(1, resolution), default).Complete();
        hashesBuffer.SetData(hashes);

        propertyBlock ??= new MaterialPropertyBlock();
        propertyBlock.SetBuffer(hashesId, hashesBuffer);
        propertyBlock.SetVector(configId, new Vector4(resolution, 1f / resolution, 0, 0));

        // Forzar binding para DX12 o Vulkan
        Shader.SetGlobalBuffer("_Hashes", hashesBuffer);
        Shader.SetGlobalVector("_Config", new Vector4(resolution, 1f / resolution, 0, 0));
        materialInstance.SetBuffer("_Hashes", hashesBuffer);
    }

    void Update()
    {
        // Si cambia resolución o seed, recalcular el buffer
        if (resolution != prevResolution || seed != prevSeed)
        {
            Initialize();
            prevResolution = resolution;
            prevSeed = seed;
        }

        if (instanceMesh == null || hashesBuffer == null || materialInstance == null)
            return;

        // Reenviar datos al material por seguridad
        propertyBlock.SetBuffer(hashesId, hashesBuffer);
        propertyBlock.SetVector(configId, new Vector4(resolution, 1f / resolution, 0, 0));

        // Bounds grande para evitar frustum culling
        var bounds = new Bounds(Vector3.zero, Vector3.one * 1000f);

        Graphics.DrawMeshInstancedProcedural(
            instanceMesh,
            0,
            materialInstance,
            bounds,
            hashes.Length,
            propertyBlock
        );
    }
}
