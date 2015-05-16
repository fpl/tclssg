# Tclssg, a static website generator.
# Copyright (C) 2013, 2014, 2015 Danyil Bohdan.
# This code is released under the terms of the MIT license. See the file
# LICENSE for details.

# Wrapper for a safe interpreter for templates.
namespace eval ::tclssg::templating::interpreter {
    namespace export *
    namespace ensemble create

    # Set variable $key to $value in the template interpreter for each
    # key-value pair in a dictionary.
    proc inject {dictionary} {
        dict for {key value} $dictionary {
            var-set $key $value
        }
    }

    # Set up the template interpreter.
    proc up {inputDir} {
        # Create a safe interpreter to use for rendering templates (the
        # template interpreter).
        ::safe::interpCreate templateInterp
        ::safe::interpAddToAccessPath templateInterp [file join \
                $inputDir \
                $::tclssg::config(templateDirName)]
        ::safe::interpAddToAccessPath templateInterp [file join \
                $::tclssg::config(skeletonDir) \
                $::tclssg::config(templateDirName)]
        # A command to set variable $name to $value in the template
        # interpreter.
        interp alias {} [namespace current]::var-set templateInterp set

        # Alias commands to be used in templates.
        foreach {command alias} {
            ::tclssg::version                   tclssg-version
            ::tclssg::utils::replace-path-root  replace-path-root
            ::tclssg::utils::dict-default-get   dict-default-get
            ::textutil::indent                  ::textutil::indent
            ::tclssg::utils::slugify            slugify
            puts                                puts
            ::tclssg::templating::inline-markdown-to-html
                                                markdown-to-html
            ::tclssg::templating::interpreter::with-cache
                                                with-cache-for-filename
            ::tclssg::pages::get-setting        get-page-setting
            ::tclssg::pages::get-data           get-page-data
            ::tclssg::pages::get-website-config-setting
                                            get-website-config-setting
            ::tclssg::pages::get-tag-list       get-tag-list
            ::tclssg::pages::get-link           get-page-link
            ::tclssg::pages::get-tags           get-page-tags
            ::tclssg::pages::get-tag-page       get-tag-page
            ::tclssg::pages::get-output-file    get-output-file
            ::msgcat::mc                        mc
            ::msgcat::mcset                     mcset
            ::msgcat::mclocale                  mclocale
            ::html::html_entities               entities
            ::tclssg::templating::parse         parse-template
            ::tclssg::read-data-file            read-data-file

            ::csv::iscomplete                   ::csv::iscomplete
            ::csv::split                        ::csv::split
            ::json::json2dict                   ::json::json2dict
        } {
            interp alias templateInterp $alias {} {*}$command
        }

        interp alias templateInterp get-rss-file {} apply {{callback id} {
            return [$callback [tclssg pages get-data $id inputFile]]
        }} $::tclssg::pages::rssFileCallback

        # Allow templates to read and source files from the templates
        # subdirectory with path failover.
        interp alias templateInterp read-template-file \
                {} ::tclssg::read-template-file-literal $inputDir
        interp alias templateInterp resolve-template-file-path \
                {} ::tclssg::resolve-template-file-path $inputDir

        interp eval templateInterp {
            proc interp-source {filename} {
                uplevel #0 [list source [resolve-template-file-path $filename]]
            }
            proc include {filename} {
                uplevel #0 [list eval \
                        [parse-template [read-template-file $filename]]]
            }
        }
    }

    # Tear down the template interpreter.
    proc down {} {
        interp delete templateInterp
    }

    # Expand template for page pageData.
    proc expand {template id {extraVariables {}}} {
        up [tclssg pages get-website-config-setting inputDir ""]
        var-set currentPageId $id
        inject $extraVariables
        set listing [tclssg templating parse $template]
        set result [interp eval templateInterp $listing]
        down
        return $result
    }

    # Run $script and cache the result. Return that result immediately
    # if the script has already been run for $filename.
    proc with-cache {filename script} {
        set cache [namespace parent]::cache
        if {[$cache exists $filename $script]} {
            set result [$cache get $filename $script]
        } else {
            set result [interp eval templateInterp $script]
            $cache set $filename $script $result
        }
        return $result
    }
} ;# namespace interpreter
