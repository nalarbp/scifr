# SCIFR

SCIFR is a development framework for creating Self-Contained Interactive Single File Reports using a Single Page Application approach. It introduces the concept of bundling an SPA as a template and mutating it with new data strings to generate web-app-like single file interactive reports. The resulting report is a single HTML file containing JavaScript code, CSS, and embedded data that users can open and interact with locally using modern web browsers. Because SCIFR-based templates/reports are self-contained and can run without a web server, developers can seamlessly integrate them with their command-line tools or pipelines.

## How to Use

To use SCIFR, follow these steps:
- Install Node.js (https://nodejs.org/en)
- Set up a template development environment using SCIFR boilerplate (`npx create-scifr my-scifr-template`)
- Start the development server (`cd my-scifr-template && npm run dev`)
- Change the content, states, etc. to suit your report demands
- Once you're happy, build it as a template using `npm run build`
- Integrate your template into your pipeline by mutating the data block

Showcase of SCIFR example reports are available at: https://scifr.fordelab.com/

## Use Case Examples

We used SCIFR to develop two pipelines: BLITSFR and METAXSFR.

### BLITSFR
BLITSFR (BLAST Interactive Tracks in Single-File Report) is a Nextflow pipeline that compares the similarity of multiple sequences using BLAST or KMA and generates a single-file interactive report with circular genome visualisation.

**Repository:** https://github.com/nalarbp/blitsfr

### METAXSFR
METAXSFR (Metagenome Taxonomic Explorer in a Single-File Report) is a Nextflow pipeline that processes taxonomic profiling reports from various metagenomics tools (Kraken2, Bracken, MetaPhlAn4) and generates an single HTML file for interactive visualisation and analysis.

**Repository:** https://github.com/nalarbp/metaxsfr

## Benchmarking

We also compared how SCIFR performed against current alternatives. Performance benchmarks and validation results are available in the `benchmarking/` directory. These include report generation time, file size and google lighthouse web performance evaluation. 

## Citation

If you use SCIFR, BLITSFR, METAXSFR, or other tools created with SCIFR, please kindly cite [Coming soon].

## Contact

For questions, suggestions, or collaborations, feel free to contact us:
- Budi Permana (b.permana@uq.edu.au) or
- Brian Forde (b.forde@uq.edu.au)

## License
This project is licensed under the Apache 2.0 - see the [LICENSE](LICENSE) for details.
