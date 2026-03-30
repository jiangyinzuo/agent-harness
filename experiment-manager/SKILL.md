---
name: experiment-manager
description: 管理项目期间的各类 experiment/benchmark，包括实验运行规范和实验数据管理规范，确保1) 实验输入、代码版本、命令、原始输出、分析脚本和结论可追溯、可复现；2) 实验结果可方便查询
---

# Experiment Manager

使用git仓库管理实验数据，每次运行完一轮实验、添加修改实验脚本、实验仓库脚本重构，都创建一次git commit。

实验管理需要保存包括但不限于以下**实验材料**，用于后续分析、复现、查询。

- 实验运行记录（raw）
    - 实验原始数据日志（output*.txt）
    - 运行benchmark的脚本（run-exp*.py）
    - 实验运行参数配置（config*.json)
    - 为了实验临时对项目修改的代码patch（code*.patch）
    - 实验运行记录（RECORDS.md）
- 数据分析总结（data-analysis）
    - 实验报告（REPORT.md）
    - 数据分析脚本
    - 整理后的图片、表格

可能的项目组织结构如下：

```
experiment/
    raw/
        common.py
        exp1/
            config-group1-v1_0.json
            config-group2-v1_0.json
            config-group1-v1_1.json
            config-group1-v1_2.json
            config-group1-v2_0.json
            config-group1-v2_1.json
            output-group1-v1_0-datetime1.txt
            output-group1-v1_0-datetime2.txt
            output-group2-v1_0-datetime3.txt
            output-group1-v1_1-datetime4.txt
            output-group1-v1_2-datetime5.txt
            output-group1-v1_2-datetime6.txt
            output-group1-v2_0-datetime7.txt
            code-v1_0.patch
            code-v2_0.patch
            code-v2_1.patch
            common.py
            run-exp1-v1_2_4.py
            run-exp1-v2_1_0.py
            RECORDS.md
        exp2/
            output-v1-0-datetime1.txt
            output-v1-0-datetime2.txt
            config-v1-0.json
            code-v1-0.patch
            run-exp2-v1-1-2.py
            RECORDS.md
    data-analysis/
        task1/
            data-analysis.py
            data.csv
            REPORT.md
        task2/
            draw-figure.py
            result.png
            REPORT.md
```


## 实验数据管理

### 实验运行记录（raw）

raw/ 目录管理实验原始数据和运行记录。其下的子目录exp1/ exp2/ ...代表不同的实验类型。

NOTE: 实验文件夹的命名，应当体现运行了什么benchmark，不要以实验对象命名。例如，你提出了优化点A，想比较它和baseline的性能，通过benchmark B来验证性能时，你应当将目录命名为exp-B，然后在
RECORDS.md中记录你本次运行实验的目的是比较优化点A和baseline之间的性能。

#### 语义化版本管理

随着项目的演进，同一个实验可能会在不同**参数、硬件资源、数据集、算法**等变量下运行。
为此，我们使用**语义化版本，即x_y_z版本号**来管理
- 实验运行脚本（run-exp.py）
- 实验原始输出数据（output.txt)
- 实验运行输入配置参数（config.json）
- 运行实验所需的patch文件（code.patch）

如果我们只是对实验脚本进行代码重构等不影响实验脚本兼容性的调整，只需新增z版本号。
如果我们的对实验脚本引入了新的运行参数，新增y版本号。
如果我们的对实验脚本做了破坏性语义变更，新增x版本号。

x_y脚本应当对x_(y-1)配置文件保持兼容。例如，run-exp1-v2_1_0.py应当能够读取`config-*-v2_0.json` 和 `config-*-v2_1.json`。

#### config-group管理

我们可能会在某一时刻，运行VAR1=1,2,3的实验；而在另一时刻，运行VAR1=4,5,6的实验。
为此，我们用不同的group来表示不同的实验组。例如`config-group1-v1_0.json`和`config-group2-v1_0.json`。

配置文件中应当包含：
- 实验运行的输入参数
- 代码的git commit + patch（如果需要）

**用config-group区分相同实验脚本、不同实验目的的实验**

有时候我们会运行不同的实验，这些实验依赖同一个run-exp脚本，但config-group不同，实验目的也不同。
这时候，请将这些实验合并到同一个exp/目录下，用不同的config-group来管理，并将不同config-group的目的
记录到RECORDS.md中。

有时候，group1 + group2 + group3用于解答一个用户的问题，而group2 + group3 + group4用于解答用户的另一个问题。

#### 时间戳管理

同一组实验可能会反复运行多次，使用datetime时间戳管理。

#### patch管理

某些实验可能需要临时修改代码，用patch管理这些临时修改的代码。

#### RECORDS.md

在文件开头，简要说明实验内容。

在每次实验运行时，
记录实验运行环境、实验注意事项、实验目的、实验脚本变更、实验运行步骤。

##### 实验注意事项

这一小节用于指导运行这项具体实验时，需要注意什么，以下是一个示例：

```
示例1：项目仓库内自带的benchmark无法在当前机器上运行，需要通过打一个临时patch来保证运行
```

##### 实验目的

例如，你可以记录你想验证优化点A相对于baseline在Benchmark B下能否性能提升。

##### 实验运行步骤

可能会分多步操作，记录你的操作，例如：

```
运行run-exp1-v2_1_0.py脚本，使用config-group1-v2_1配置，获得输出output-group1-v2_1-datetime1.txt
git apply code-v2_1.patch，向代码库添加xxx改动
再次运行run-exp1-v2_1_0.py脚本，使用config-group2-v2_1配置，获得输出output-group2-v2_1-datetime1.txt
```

### 数据分析总结（data-analysis）

数据分析是面向用户问题的，因此，一项实验数据分析任务task1/可能会依赖多项实验（exp1/，exp2/）.
因此，和exp/的命名不同，task的命名应该面向用户关心的问题。
例如，你提出了优化点A，想比较它和baseline的性能，通过benchmark B来验证性能时，应当将task文件夹命名为task-optimization-A，而不是task-B。

#### REPORT.md

最好通过python脚本来辅助生成REPORT.md，这样在重复运行实验时，可以减少写报告的工作量。
不过，某些结论性质的段落还请根据实验数据作结论，你可以用if-else分支预设不同数据结果下的结论；也可以先设置占位符，根据实验结果，智能地给出结论。

## 其它注意事项

1. 和用户讨论你的实验计划

收到用户请求后，首先陈述你的实验计划，包括

- 向用户确认实验git仓库位置
- 运行实验时，你会
    - 新增实验类型，还是在已有的实验类型上做实验？
    - 修改实验脚本，升级x/y/z版本号？还是仅新增/修改实验配置？还是单纯重复跑一轮实验？
    - 如果涉及到代码修改，你大致会怎么修改patch？

2. 运行前确认事项

- 机器资源是否被他人占用，以至于影响实验？注意，如果他人占用的资源不影响实验，可以继续执行；如果他人占用的资源影响了实验，请向用户报告，**严禁影响他人实验！**
- 当前项目中是否有未保存的代码，会影响到你的实验？如果会，请询问用户解决办法。
- 运行某个具体实验前，先浏览该实验的RECORDS.md，获悉该实验的注意事项。

3. 实验脚本重构

不同版本、不同实验间的脚本可能包含一些公共函数（common.py）。请适当对实验脚本进行重构，减少冗余代码。
