//--------------------------------------------------------------------
// 文件名:		DynamicWalkFlagCompress.h
// 内  容:		
// 说  明:		
// 创建日期:	2013年3月26日
// 创建人:		沈奇伟
// 版权所有:	苏州蜗牛电子有限公司
//--------------------------------------------------------------------

#ifndef _DYNAMICWALKFLAGCOMPRESS_H
#define _DYNAMICWALKFLAGCOMPRESS_H

#include "../public/macros.h"

// 行走标记信息压缩

class CDynamicWalkFlagCompress
{
private:
	// 节点类型
	enum 
	{
		NODE_BRANCH,	// 带有子节点
		NODE_ORIGINAL,	// 未压缩的值
		NODE_COMPRESS,	// 压缩后的值
	};

	// 节点数据
	struct node_data_t
	{
		int nType;
		size_t nScale;
		size_t nRow;
		size_t nCol;
		node_data_t* pChildren[4];
	};

public:
	CDynamicWalkFlagCompress();
	~CDynamicWalkFlagCompress();

	// 压缩
	bool Compress(size_t scale, const unsigned char* pdata, size_t size);
	// 解压缩
	bool Decompress(size_t scale, const unsigned char* pdata, size_t size);

	// 获得结果数据
	const unsigned char* GetResultData() const { return m_pResultData; }
	size_t GetResultSize() const { return m_nResultSize; }

	// 从压缩数据中获得标记值
	static bool GetFlag(size_t scale, size_t row, size_t col,
		const unsigned char* pdata, size_t size, unsigned char& value);

private:
	CDynamicWalkFlagCompress(const CDynamicWalkFlagCompress&);
	CDynamicWalkFlagCompress& operator=(const CDynamicWalkFlagCompress&);

	void ReleaseAll();

	// 删除节点
	void DeleteNode(node_data_t* node);
	// 设置节点
	node_data_t* CreateNode(size_t scale, size_t row, size_t col,
		const unsigned char* pdata, size_t size);
	// 压缩节点
	size_t CompressNode(node_data_t* node, const unsigned char* pdata, 
		size_t size);
	// 数据解压缩
	bool DecompressData(size_t scale, size_t row, size_t col,
		const unsigned char* pdata, size_t size, size_t& pos);

	// 从压缩数据中获得标记
	static bool GetFlagData(size_t scale, size_t row, size_t col, 
		const unsigned char* pdata, size_t size, size_t& pos, 
		unsigned char& value);

private:
	node_data_t* m_pRoot;
	size_t m_nScale;
	unsigned char* m_pResultData;
	size_t m_nResultMemSize;
	size_t m_nResultSize;
};

#endif // _DYNAMICWALKFLAGCOMPRESS_H

