import os
import re

def crawl_folders( target_dir = r'data/' ):
	zst_file_path_list = []
	gzip_file_path_list = []

	file_basename_to_path = {}
	path_to_file_basename = {}

	for root, dirs, files in os.walk( target_dir ):
		for file in files:
			filename = re.sub( pattern = ".gz$", repl = "", string = file )
			filename = re.sub( pattern = ".zst$", repl = "", string = filename )

			filepath = os.path.join( root, filename )

			if re.search( pattern = ".pickle$", string = filename ) or re.search( pattern = ".tar$", string = filename ):
				# don't try to compress pickled files
				continue
			elif ( re.search( pattern = ".fastq$", string = filename ) or re.search( pattern = "_sequence.txt$", string = filename ) or re.search( pattern = ".fqs$", string = filename ) ):
				# this is a sequence file
				# they have the form of fastq, sequence.txt, or fqs [ FASTQ, Sanger scale ]
				zst_file_path_list.append( filepath )

				modified_name = re.sub( pattern = "\.", repl = "_", string = filename )
				file_basename_to_path[ modified_name ] = filepath

				path_to_file_basename[ filepath ] = modified_name
			else:
				# this is not a sequence file
				gzip_file_path_list.append( filepath )

	return zst_file_path_list, gzip_file_path_list, file_basename_to_path, path_to_file_basename

zst_file_path_list, gzip_file_path_list, basename_path_map, path_basename_map = crawl_folders( target_dir = r'data/' )

basename_list = list( basename_path_map.keys() )

rule all:
	input:
		expand( "{file}.gz", file = gzip_file_path_list ),
		expand( "output/md5_sums/{file_base}_raw.md5", file_base = basename_list ),
		expand( "output/file_sizes/{file_base}_size_raw.txt", file_base = basename_list ),
		expand( "output/file_sizes/{file_base}_size_zip.txt", file_base = basename_list ),
		expand( "{file}.zst", file = zst_file_path_list ),
		expand( "output/md5_sums/{file_base}_zst.md5", file_base = basename_list ),
		expand( "output/file_sizes/{file_base}_size_zst.txt", file_base = basename_list )

rule run_pigz:
	input:
		"{file}"
	output:
		"{file}.gz"
	threads: 10
	resources:
		mem_mb = 2 * 1024
	singularity:
		"docker://thatdnaguy/ubuntu_general:v20.04_02"
	shell:
		"pigz --best -p {threads} {input}"

rule raw_and_gzip_size_md5:
	input:
		lambda wildcards: "%s.gz" % ( basename_path_map[ wildcards.file_base ] )
	output:
		raw_md5 = "output/md5_sums/{file_base}_raw.md5",
		raw_size = "output/file_sizes/{file_base}_size_raw.txt",
		zip_size = "output/file_sizes/{file_base}_size_zip.txt",
		rezip = "output/rezipped/{file_base}.rezipped"
	params:
		no_gz_path = lambda wildcards: "%s" % ( basename_path_map[ wildcards.file_base ] )
	threads: 10
	resources:
		mem_mb = 5 * 1024
	singularity:
		"docker://thatdnaguy/ubuntu_general:v20.04_02"
	shell:
		"gunzip {input} && "
		"du --block=1 {params.no_gz_path} > {output.raw_size} && "
		"md5sum {params.no_gz_path} > {output.raw_md5} && "
		"pigz --best -p {threads} {params.no_gz_path} && "
		"du --block=1 {input} > {output.zip_size} && "
		"touch {output.rezip}"

rule zstd_compress:
	input:
		rezip = lambda wildcards: "output/rezipped/%s.rezipped" % ( path_basename_map[ wildcards.path ] )
	output:
		"{path}.zst"
	params:
		no_gz_path = lambda wildcards: "%s" % ( wildcards.path ),
		gz_path = lambda wildcards: "%s.gz" % ( wildcards.path )
	threads: 10
	resources:
		mem_mb = 5 * 1024
	singularity:
		"docker://thatdnaguy/ubuntu_general:v20.04_02"
	shell:
		"gunzip {params.gz_path} && "
		"zstd -19 -T{threads} {params.no_gz_path} && "
		"rm {params.no_gz_path}"

rule zstd_md5_size:
	input:
		lambda wildcards: "%s.zst" % ( basename_path_map[ wildcards.file_base ] )
	output:
		zst_size = "output/file_sizes/{file_base}_size_zst.txt",
		zst_md5 = "output/md5_sums/{file_base}_zst.md5"
	threads: 1
	resources:
		mem_mb = 5 * 1024
	singularity:
		"docker://thatdnaguy/ubuntu_general:v20.04_02"
	shell:
		"du --block=1 {input} > {output.zst_size} && "
		"zstd --decompress --stdout {input} | md5sum > {output.zst_md5}"
