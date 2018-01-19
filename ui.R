library(shiny)


# When updating the applet, be sure to run GenerateDataObjects.R if the data has changed. 
# GenerateDataObjects.R contains code to pre-process the data files - 
# this does not need to happen every time the applet is loaded, but should happen when the
# underlying data files change. 

# Data/uiStart.rda and Data/serverStart.rda depend on GenerateDataObjects

# Variables to populate the drop-down menus in the tool
load("Data/uiStart.rda")

# Intro.R creates HTML from the 4 text files in ./Data (text, titles, captions, and figures). 
# This code creates the text/HTML for the expandable panels on the "Introduction" page of the applet. 
# Specifically, creates list.of.panels 
source("Code/Intro.R")
# Once the text, figures, etc. are stable, this function call 
# could be moved into GenerateDataObjects.R
# So long as the object list.of.panels is saved in uiStart.rda

# About Shiny/Bootstrap integration: 
# Bootstrap (and Shiny) divide a page into 12 columns, 
# so that these columns can be rearranged for mobile devices.
# Every input belongs in a column so that it can be resized. 
# http://getbootstrap.com/css/
# in Shiny:
#    fluidRow() allows columns to be rearranged for mobile browsers.
#    fixedRow() would make a column that would not rearrange.

# Function to print footer in each tab
footer <- function(){
  img(src="Footer.jpg", width='100%', height='auto')
} # end footer function definition

# Define header to be used across all tabs
header <- function(){
  
  # CSS files and other links which belong in the header
  
  tags$head(
    # CSS for bootstrap modifications: 
    #    Change the size of the title and Tab labels, 
    #    make input labels a bit larger.
    singleton(tags$link(href="addons.css", rel="stylesheet")),
    
    # Bootstrap CSS for animated panels, etc. 
    # Reference: http://getbootstrap.com/css/
    singleton(tags$link(href="bootstrap.min.css", rel="stylesheet")),
    
    # Resizer
    singleton(tags$script(src="js/iframeResizer.contentWindow.min.js", type="text/javascript"))
  )
  
} # end header function definition

# Agronomy address
agronomy <- function(space=T){
  span(
    p("Department of Agronomy,", class="nospace"),
    p("Agronomy Hall, ", class="nospace"),
    p("Ames, IA  50011"),
    style=ifelse(space, "display:inline-block;margin:5%;", "display:inline-block;")
  )
}

# copyright info
# space parameter indicates whether there should be a bit of extra margin
copyright <- function(space=T){
  span(
    p("Copyright © 2015", class="nospace"),
    p("Iowa State University", class="nospace"),
    p("All rights reserved."),
    style=ifelse(space, "display:inline-block;margin:5%;", "display:inline-block;")
  )
} # end copyright info
  
# I define the intro and tool tabs in functions
# because it's much easier to make the code modular
# when each tab is in a separate space and clearly delineated 

intro <- function(){
  tabPanel(
    "Introduction", # name
    
    # Set value = "intro" so that we could link to this tab
    value = "intro",
    
    # Intro page title
    div(
      align="center", 
      h1("Understanding interactions between soybean planting date and maturity across environments")
    ), 
    
    # Space
    br(),
    
    # Everything but the footer and title in this row!
    fluidRow(
      
      # Side panel/column with pictures and information about the project itself
      column(
        width=3, 
        
        # Iowa Soybean Assoc. Logo
        div(
          img(
            src="SoybeanAssociation.jpg", 
            width="75%", height="auto"
          ), style="text-align:center;"
        ),
        
        br(),
        br(),  
        
        # Iowa Soybean Research Logo
        div(
          img(
            src="ISRCwordmark.png", 
            width="75%", height="auto"
          ), style="text-align:center;"
        ),
        
        br(),
        br(),
        
        # Cute baby soybean sprout
        img(src="PhotoIIISoybeanemergen.jpg", width='100%', height='auto'),
        
        br(), 
        br(),
        
        # Expandable set of tab panels with 
        # Disclaimer, Acknowledgements, Contact Info, and References
        div(
          class="panel-group", 
          id="accordion", 
          role="tablist", 
          "aria-multiselectable"="true", # Can multiple panels be expanded at once?
          
          # Output HTML of the last 4 tab panels
          HTML(paste0(list.of.panels[17:20], collapse="\n"))
        ),
        
        # Fuzzy soybean in the field
        img(src="PhotoI.jpg", width='100%', height='auto'),
        
        br(), 
        br()
        
      ), # End sidebar column
      
      # This column contains the expandable panels. 
      column(
        width=9,
        div(
          class="panel-group", 
          id="accordion", 
          role="tablist", 
          "aria-multiselectable"="true", # Can multiple panels be expanded at once?
          
          # Output HTML of the first 16 tab panels, with matching figures, etc.
          HTML(paste0(list.of.panels[1:16], collapse="\n")) 
        )
      ) # End column with expandable panels
      
    ), # End content row
    
    # Footer image with ISU Extension and copyright info. 
    footer()
    
  ) # End tabPanel definition
  
} # End intro() function definition

tool <- function(){
  tabPanel(
    
    # Panel title
    title = "Tool",
    
    # Set value = "tool" so that we can link to this tab
    value="tool",
    
    # Input panel
    wellPanel(
      fluidRow(
        # Comparison Variable Help
        column(2, offset=1, 
               br(),
               p("Select a variable to compare up to 3 different values for that variable.")
        ),
        
        # Comparison Variable input: input$compare can take values "Location", "PlantDay", or "MG"
        #    but we want it to have nice labels, not variable names. 
        column(2,
               radioButtons("compare", label="Comparison Variable", 
                            choices=c("Location"="Location", 
                                      "Planting Date"="PlantDay", 
                                      "Maturity Group"="MG"), 
                            inline=F)
        ),
        
        #  This column contains rows because we want to have things above and below a 3-col layout.
        column(6,
               # Input variable help text
               fluidRow(
                 p(align="center", "Click on the boxes below to see what options are available.")
               ),
               
               # 3 columns of input variables
               fluidRow(
                 # Location input, with values populated by uiStart.rda
                 column(4, uiOutput("location")),
                 # Planting dates
                 column(4, uiOutput("planting")),
                 # Maturity groups
                 column(4, uiOutput("maturity"))
               ),
               
               # Help text on entering variables
               fluidRow(
                 p(align="center", 
                   "You can type or select options to add them 
                   (use backspace to remove a selected option, 
                   and enter to add an option if you are typing)."
                 )
               )
        )
      ) # End main fluidRow in WellPanel
    ), # End wellpanel 
    
    # This row contains the soybean development timeline output
    fluidRow(
      
      # First, column with the plot and caption
      column(10, 
             # Plot
             plotOutput("DevelopmentPlot", height=400),
             
             # Caption
             div(align="center", 
                 p(strong("Fig. 1"), 
                   "Development timeline of soybean cultivars. 
                   Outliers (if applicable) are shown as unfilled circles."),
                 helpText("About these plots:", # Links on how to read box and violin plots
                          a(href="https://en.wikipedia.org/wiki/Box_plot", "Box plot"), ", ", 
                          a(href="https://en.wikipedia.org/wiki/Violin_plot", "Violin plot"))
             )
      ), # End Development Timeline plot column
      
      # Column with input options
      column(2, 
             br(),
             wellPanel(
               # Well Panel Title
               h4("Plot Options"),
               
               # Input plot type. 
               radioButtons("plottype", "Plot Type", 
                            choices=c("Box Plot" = 1, "Violin Plot" = 2), 
                            selected=1), # default to box plot
               
               # Input variable for facets on the timeline
               checkboxInput("facets", "Show sub-plots", value=FALSE)
               
             ), # End WellPanel
             
             wellPanel(
               
               # Iowa Soybean Assoc. Logo
               img(src="SoybeanAssociation.jpg", width="100%", height="auto")
               
             ), # End Logo WellPanel
             
             wellPanel(
               
               # Iowa Soybean Research Center. Logo
               img(src="ISRCwordmark.png", width="100%", height="auto")
               
             ) # End Logo WellPanel             
             
      ) # End Development Timeline Plot Options column
      
    ), # End Development  Timeline row
    
    # This row contains the relative yield plots and associated input options
    fluidRow(
      # Yield by MG plot output and caption
      column(5,
             # Plot
             plotOutput("YieldByMGPlot", height=400),
             
             # Caption
             div(align="center", 
                 p(strong("Fig. 2"), 
                   "Relationship between relative yield and soybean cultivar (maturity group) 
                   for a specific planting date(s) and location(s). 
                   For Location and Planting Date comparison variables, 
                   vertical dotted line(s) indicates the appropriate maturity 
                   group for use in a specific location and/or planting date.")
             )
      ), # End Relative Yield x MG column
      
      # Input variables for the two relative yield plots
      column(2, br(), 
             
             # Well panel because input
             wellPanel(
               
               # Radio button input$plottype2: Fitted line or box plot?
               radioButtons("plottype2", "Relative Yield by MG Plot Type: ", 
                            choices=c("Fitted Line"=2, "Box Plot" = 1), 
                            selected=2), # Default to fitted line
               
               # Space between titles
               br(),
               
               # Input Title
               strong("Both Plots:"),
               
               # The following inputs are boolean/logical: they take T/F or 1/0 values. 
               
               # input$points indicates whether to show points or not. 
               checkboxInput("points", 
                             label="Show Points"),
               
               # input$ci indicates whether to show the prediction interval
               checkboxInput("ci", 
                             label="Show 95% Prediction Interval"),
               
               # input$failed indicates whether to include trials which failed due to weather, etc. 
               checkboxInput("failed", 
                             label="Include Failed Trials?"),
               
               # input$newdata2 indicates whether to show data from 2014 trials.
               checkboxInput("newdata2", 
                             "Show 2014/2015 measured data (if available)")
             )
      ), # End Relative Yield plot input column
      
      column(5,
             
             # Plot
             plotOutput("YieldByPlantingPlot", height=400),
             
             # Caption
             div(align="center", 
                 p(strong("Fig. 3"), 
                   "Relationship between relative yield and date of planting 
                   for a specific cultivar (maturity group) and location. 
                   For Location and Maturity Group comparison variables, 
                   vertical dotted line(s) indicates the optimum planting 
                   date(s) for maximizing yield under a particular combination 
                   of cultivar and location.")
                 )
             ) # End Relative Yield x Planting Date column
      
    ), # End Relative Yield row
    
    # Footer image with ISU Extension and copyright info. 
    footer()
    
  ) # End TabPanel definition
  
} # End tool() function definition


# Define UI
shinyUI(
  
  # navbarPage has a bar at the top (or bottom) with links to navigate between tabs
  navbarPage(
    
    # Page title
    title="",
    
    # Use dark bar with light text
    inverse=TRUE,
    
    # id (important for linking to tabs)
    id = "tab",
    
    # Header
    header = header(), 
    
    # Create introduction tab
    intro(),
    
    # Create tool in its own tab
    tool()
    
  ) # end navbarPage definition

) # end UI definition
