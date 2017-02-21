//--------------------------------------------------------------------
// �ļ���:		MemPool.h
// ��  ��:		
// ˵  ��:		
// ��������:	2011��2��11��
// ������:		½����
// ��Ȩ����:	������ţ�������޹�˾
//--------------------------------------------------------------------

#ifndef _MEMPOOL2_H
#define _MEMPOOL2_H

#include <stddef.h>

// �ڴ��

class CMemPool
{
private:
	enum { ALIGN = 8 };
	enum { ALIGN_SHIFT = 3 };
	enum { MAX_BYTES = 128 };
	enum { FREELIST_NUM = 16 };

	struct alloc_obj_t
	{
		alloc_obj_t* free_list_link;
	};

	struct alloc_chunk_t
	{
		alloc_chunk_t* chunk_link;
		size_t chunk_size;
	};

public:
	CMemPool();
	~CMemPool();

	// �����ڴ�
	void* Alloc(size_t size);
	// �ͷ��ڴ�
	void Free(void* ptr, size_t size);
	// ����ڴ�����ڴ���
	size_t GetPoolSize() const;
	// ����ڴ�ؿ����ڴ���
	size_t GetFreeSize() const;
	
private:
	CMemPool(const CMemPool&);
	CMemPool& operator=(const CMemPool&);
	
	// �ͷ������ڴ��
	void FreeAll();
	// �����ڴ��
	char* ChunkAlloc(size_t size, int& nobjs);
	// ����ڴ�
	void* Refill(size_t n);

private:
	alloc_chunk_t* m_pFirstChunk;
	alloc_obj_t* m_pFreeList[FREELIST_NUM]; 
	char* m_pStartFree;
	char* m_pEndFree;
};

#endif // _MEMPOOL2_H
