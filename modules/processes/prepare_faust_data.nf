nextflow.preview.dsl=2

process prepareFAUSTData {
    // [ directives ]
    container "rglab/faust-nextflow:1.0.0"
    label "high_memory"

    input:
        // User
        file input_gating_set_directory_channel
        file active_channels_path_channel
        file channel_bounds_path_channel
        file supervised_list_path_channel
        // Implicit
        // N/A
        // Execution Specific
        val imputation_hierarchy
        val experimental_unit
        val starting_cell_population
        // Architecture
        val project_path
        val debug_flag

    output:
        path "*faustData/metaData", emit: metadata_directory
        path "*faustData/sampleData", emit: samples_data_directory
        path "*faustData/expUnitData/*", emit: experimental_unit_directories
        // Needed because the user might not pass this in and default value is determined by gating set
        env FAUST_NAME_OCCURRENCE_NUMBER, emit: default_name_occurrence_number_file

    script:
        """
        R --no-save <<code
        # ----------------------------------------------------------------------
        # -------------------------
        # Environment
        # -------------------------
        library("flowWorkspace")
        library("faust")

        # -------------------------
        # FAUST Data
        # -------------------------
        gating_set <- flowWorkspace::load_gs("${input_gating_set_directory_channel}")

        active_channels_rds_object <- readRDS("${active_channels_path_channel}")
        channel_bounds_rds_object <- readRDS("${channel_bounds_path_channel}")
        supervised_list_rds_object <- readRDS("${supervised_list_path_channel}")
        if(is.null(active_channels_rds_object)){
            active_channels_rds_object<-flowWorkspace::markernames(gating_set)
        }else if(is.na(active_channels_rds_object)){
            active_channels_rds_object<-flowWorkspace::markernames(gating_set)
        }
        if(is.null(channel_bounds_rds_object)){
            channel_bounds_rds_object<-""
        }else if(is.na(channel_bounds_rds_object)){
            channel_bounds_rds_object<-""
        }
        if(is.null(supervised_list_rds_object)){
            supervised_list_rds_object<-NA
        }
        gating_set_p_data <- flowWorkspace::pData(gating_set)
        sample_names_rds_object <- flowWorkspace::sampleNames(gating_set)

        saveRDS(gating_set_p_data, "./gating_set_p_data.rds")
        saveRDS(sample_names_rds_object, "./sample_names.rds")

        project_path <- normalizePath("${project_path}")

        # Create default `name_occurrence_number`
        name_occurrence_number <- ceiling((0.1 * length(gating_set)))
        export_string <- paste0("export FAUST_NAME_OCCURRENCE_NUMBER=", name_occurrence_number)
        file_handle <- file("faust_name_occurrence_number.txt")
        writeLines(export_string, file_handle)
        close(file_handle)

        # -------------------------
        # Run FAUST
        # -------------------------
        faust:::.initializeFaustDataDir(activeChannels=active_channels_rds_object,
                                        channelBounds=channel_bounds_rds_object,
                                        supervisedList=supervised_list_rds_object,
                                        startingCellPop="${starting_cell_population}",
                                        projectPath=project_path)
        # -----
        faust:::.constructAnalysisMap(gspData=gating_set_p_data,
                                      sampNames=sample_names_rds_object,
                                      imputationHierarchy="${imputation_hierarchy}",
                                      experimentalUnit="${experimental_unit}",
                                      projectPath=project_path,
                                      debugFlag=${debug_flag})
        # -----
        faust:::.extractDataFromGS(gs=gating_set,
                                   activeChannels=active_channels_rds_object,
                                   startingCellPop="${starting_cell_population}",
                                   projectPath=project_path,
                                   debugFlag="${debug_flag}")
        # -----
        faust:::.processChannelBounds(channelBounds=channel_bounds_rds_object,
                                      samplesInExp=sample_names_rds_object,
                                      projectPath="${project_path}",
                                      debugFlag=${debug_flag})
        # -----
        faust:::.makeRestrictionMatrices(channelBounds=channel_bounds_rds_object,
                                         samplesInExp=sample_names_rds_object,
                                         projectPath="${project_path}",
                                         debugFlag=${debug_flag})
        # -----
        faust:::.prepareExperimentalUnits(projectPath="${project_path}")

        # ----------------------------------------------------------------------
        code

        # Export env variables generated from gating set
        source "faust_name_occurrence_number.txt"
        # env
        """
}