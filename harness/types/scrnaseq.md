# scRNA-seq 分析 Harness

> 历史数据：35 个 session 中最高频的分析类型。
> 最高频问题：cluster 注释错误（反复出现）。

---

## 标准流程

```
1. 数据读取与QC（Seurat/Scanpy）
2. 过滤、归一化、高变基因选择
3. 降维（PCA → UMAP）与聚类
4. 细胞类型注释（SingleR / 手动 marker）
5. 差异表达（FindAllMarkers / FindMarkers）
6. 富集分析（clusterProfiler）
7. [可选] inferCNV / CytoTRACE / 细胞通讯 / 拟时序
```

---

## 关键检查点

### 注释准确性（P0 — 最高频历史问题）
- 注释完成后 **必须** 展示每个 cluster 的 top5 marker 基因
- marker 必须与已知文献/数据库交叉验证
- 如果任何 cluster 的 marker 与注释不一致 → 停下来修正
- 禁止在未验证注释准确性前进行任何下游分析

### 聚类分辨率
- 必须说明为什么选这个分辨率（如 clustree 分析结果）
- 过高分辨率导致过度分群 → 检查是否有生物学意义很小的 cluster

### 批次效应
- 多样本 **必须** 考虑整合方法（Harmony / CCA / RPCA）
- Harmony 整合后 **必须** 重新检查 cluster 结构是否合理
- 记录整合前后 UMAP 的对比

### DE 方法选择
- Seurat FindMarkers 默认 Wilcoxon
- 大样本（每组>50 cells）考虑 MAST 或 pseudobulk
- min.pct 和 logfc.threshold 参数必须与 plan.md 一致

### Doublet 检测
- 建议使用 DoubletFinder 或 scDblFinder
- 如果跳过，必须在 plan.md 风险部分说明理由

---

## 已知陷阱

| 陷阱 | 防护措施 |
|------|---------|
| cluster 注释直接复制 SingleR 结果不验证 | 必须展示 marker 证据 |
| SoupX 环境 RNA 污染未处理 | QC 阶段检查并处理 |
| inferCNV 参考细胞选错导致假阳性 | 记录参考细胞选择理由 |
| Harmony 过度校正抹掉生物学差异 | 整合前后 UMAP 对比 |
| 注释用的 marker 来自不同物种/组织 | 确认 marker 来源匹配 |
| FindMarkers 的 ident.1/ident.2 方向搞反 | 明确 log2FC 正方向含义 |
