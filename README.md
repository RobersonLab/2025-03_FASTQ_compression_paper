# 2025 file sizes for FASTQ cold archives

This project was part of our attempt to optimize the cold storage of our FASTQ archive. Zlib is often used for archiving files because it's well-developed and stable. Zstandard is a newer algorithm that can take advantage of more modern CPU architecture to reduce compressed file sizes and stream the output of an archive faster than zlib.

We used Snakemake to organize the testing for file sizes for raw, zlib compressed, and zstandard compressed FASTQ files. The analysis was performed using Docker images with Singularity.

The data used for the analysis is available from [FigShare](https://figshare.com/articles/dataset/FASTQ_file_sizes_with_no_compression_gzip_or_zstandard/28616294).

If you want to recreate the analysis, clone the repository and run the 01 analysis R Markdown file. It will download the data file and run the analysis.

## Requirements
- R Studio
- R packages
  - broom
  - here
  - reshape2
  - tidyverse
  - uuid
