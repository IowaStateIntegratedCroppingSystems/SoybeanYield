library(shiny)
library(ggplot2)
library(reshape2)
library(plyr)
library(dplyr)
library(lubridate)
library(stringr)
library(splines)

load("Data/serverStart.rda")
load("Data/uiStart.rda")

fix.na.data <- function(df){
  ret <- unique(df[,c("Location", "PlantDay", "MG", "Stage")])
  if(sum(!is.na(df$Date))>0){
    ret$text <- " " 
  } else {
    ret$text <- "Not Achieved"
  }
  return(ret)
}



# enlarge font for session 
theme_set(theme_bw(24))

shinyServer(function(input, output, session) {
  
  # Render output options in response to comparison variable choice
  
  output$location <- renderUI(
    if(input$compare=="Location"){
      # If location is chosen to compare, output a selectizeInput list
      selectizeInput("location", label="Select location(s)", 
                     choices=locations, selected="Central Iowa", 
                     multiple=TRUE, options=list(maxItems=3))
    } else {
      # If location is not chosen, but was previously chosen, 
      # create a selectInput element with the first previously chosen value
      # as the selected value
      if(isolate(length(input$location)>0)){
        selectInput("location", label="Select location(s)", 
                    choices=locations, selected=isolate(input$location[1]))
      } else {
      # If location is not chosen and has never been specified, 
      # use Ames as the default value
        selectInput("location", label="Select location(s)", 
                    choices=locations, selected="Central Iowa")
      }
    })
  
  output$planting <- renderUI(
    if(input$compare=="PlantDay"){
      # If PlantDay is chosen to compare, output a selectizeInput list
      selectizeInput("planting", label="Select planting date(s)", 
                     choices=planting.date, selected="5-May", 
                     multiple=TRUE, options=list(maxItems=3))
    } else {
      # If PlantDay is not chosen, but was previously chosen, 
      # create a selectInput element with the first previously chosen value
      # as the selected value
      if(isolate(length(input$planting)>0)){
        selectInput("planting", label="Select planting date(s)", 
                    choices=planting.date, selected=isolate(input$planting[1]))
      } else {
        # If location is not chosen and has never been specified, 
        # use 5-May as the default value
        selectInput("planting", label="Select planting date(s)", 
                    choices=planting.date, selected="5-May")
      }
    })
  
  output$maturity <- renderUI(
    if(input$compare=="MG"){
      # If MG is chosen to compare, output a selectizeInput list
      selectizeInput("maturity", label="Select maturity group(s)", 
                     choices=seq(0, 5.5, by=0.5), selected=2.5, 
                     multiple=TRUE, options=list(maxItems=3))
    } else {      
      # If MG is not chosen, but was previously chosen, 
      # create a selectInput element with the first previously chosen value
      # as the selected value
      if(isolate(length(input$maturity)>0)){
        selectInput("maturity", label="Select maturity group(s)", 
                    choices=seq(0, 5.5, by=0.5), selected=isolate(input$maturity[1]))
      } else {
        # If location is not chosen and has never been specified, 
        # use MG=2.5 as the default value
        selectInput("maturity", label="Select maturity group(s)", 
                    choices=seq(0, 5.5, by=0.5), selected=2.5)
      }
    })
  
  
  # Monitor link to tool tab from intro:
  observe({
    
    # create a dependency on the toTool input object
    if(input$toTool == 0) return(NULL)
    
    updateTabsetPanel(session, "tab", selected="tool")
  })
  
  # Function to draw the development timeline, with options for plot type and faceting. 
  drawDevelopmentPlot <- reactive({
    
    # Filter data according to user input
    longdata.sub <- filter(longyield, MG%in%input$maturity & 
                             Location%in%input$location & 
                             PlantDay%in%input$planting) 
    longdata.sub$Location <- factor(longdata.sub$Location, levels=input$location, ordered = T)
    longdata.sub$facet <- longdata.sub[,input$compare]
    
    # Draw a "please input" plot if no rows are found, otherwise, plot data.
    if(nrow(longdata.sub)==0){
      plot <- ggplot() + 
        geom_text(aes(x=0, y=0, label="Please input\na location,\nplanting date,\n and maturity group."), size=20) +
        xlab("") + ylab("") + theme_bw() + 
        theme(axis.text=element_blank(), axis.ticks=element_blank(), title=element_blank())
    } else {
      
      # Fix NAs and calculate location for "Not Acheived" label
      textdata <- longdata.sub%>%group_by(Location, PlantDay, MG, Stage) %>% do(fix.na.data(.))
      textdata <- merge(textdata, longdata.sub%>%group_by(Stage)%>%summarize(y=mean(Date, na.rm=T), ymax=max(Date, na.rm=T)))
      if(sum(is.na(textdata$text))>0){
        textdata$text[is.na(textdata$text)] <- " "
      }
      textdata$facet <- textdata[,input$compare]
      
      # merge in maximum values to calculate ymax for NA values
      tmp <- names(textdata)
      textdata <- merge(textdata, maxvals[[input$compare]][,c(1, 2, 4)], all.x=T, all.y=F)
      textdata$y[is.na(textdata$y)] <- textdata$ymax.backup[is.na(textdata$y)]
      textdata$ymax[is.na(textdata$ymax)] <- textdata$ymax.backup[is.na(textdata$ymax)]
      textdata <- textdata[,which(names(textdata)%in%tmp)]
      
      # Add variable seconds to the planting date (to get "boxplots" for planting date stage)
      second(longdata.sub$Date) <- (longdata.sub$PlantDay%in%input$planting)*(longdata.sub$Stage=="Planting")*sample(1:2, nrow(longdata.sub), replace=T)
      
      # Get yield data (wide form)
      yield.sub <- filter(yield, MG%in%input$maturity & 
                            Location%in%input$location & 
                            PlantDay%in%input$planting)
      yield.sub$facet <- yield.sub[,input$compare]
      
      # Create guide lines between maturity stages
      guidelines <- expand.grid(xintercept=seq(.5, 5.5, 1), facet=unique(yield.sub$facet))
      
      # Calculate frost dates and add variability so lines don't entirely overlap
      frost.date.df <- yield.sub %>% 
        group_by(Location, PlantDay, MG, facet) %>% 
        do(data.frame(frost.date=floor_date(quantile(.$Date.of.first.frost2, .5, na.rm=T), "day"), 
                      y=.5, 
                      label="First Frost Likely")) %>%
        as.data.frame()
      hour(frost.date.df$frost.date) <- sample(0:11, nrow(frost.date.df))
      
      # Calculate lower bound and upper bound on frost date, plus median line for all locations, etc. 
      frost.date.df$frost.date.lb <- floor_date(
        quantile(
          filter(yield, MG%in%input$maturity & 
                   Location%in%input$location & 
                   PlantDay%in%input$planting)$Date.of.first.frost2, 
          .25, na.rm=T), "day")
      frost.date.df$frost.date.ub <- 
        floor_date(quantile(filter(yield, MG%in%input$maturity & 
                                     Location%in%input$location & 
                                     PlantDay%in%input$planting)$Date.of.first.frost2, 
                            .75, na.rm=T), "day")
      frost.date.df$med.frost <- 
        floor_date(quantile(filter(yield, MG%in%input$maturity & 
                                     Location%in%input$location & 
                                     PlantDay%in%input$planting)$Date.of.first.frost2, 
                            .5, na.rm=T), "day")
      frost.date.df$textlabel <- 
        floor_date(median(frost.date.df$frost.date), "day")

      
      if(input$plottype=="1"){
        # Boxplot
        plot <- ggplot() + 
          stat_boxplot(aes(x=Stage, y=Date, fill=factor(facet), color=factor(facet)), 
                       alpha=.3, shape=1, position=position_dodge(), data=longdata.sub, width=0.9)
      } else {
        # Violin plot
        plot <- ggplot() + 
          geom_violin(aes(x=Stage, y=Date, fill=factor(facet), color=factor(facet)), 
                      alpha=.3, data=longdata.sub, scale="width", adjust=2)
      }
      
      # Function to label facets correctly - MG: __, Location: __, Planting Date: __
      label_facet <- function(x, y){
        paste0(gsub("PlantDay", "Planting Date", input$compare), ": ", y)
      }
      
      # Add facets?
      if(input$facets){
        plot <- plot + facet_grid(.~facet, labeller=labeller(facet=label_facet))
      }
      
      # Other plot stuff
      plot <- plot + 
        # "Not Acheived" labels
        geom_text(aes(x=Stage, y=ymax, ymax=ymax, label=text, color=factor(facet)), 
                  data=textdata, position=position_dodge(width=0.9), hjust=1, show_guide=F) + 
        # Frost rectangle
        geom_rect(aes(ymin=frost.date.lb, ymax=frost.date.ub, xmin=.5, xmax=5.5), alpha=.05, fill="black", data=frost.date.df) + 
        # Frost label
        geom_text(aes(y=textlabel, x=y, label=label), 
                  data=unique(frost.date.df[,c("textlabel", "y", "label")]), 
                  hjust=1, vjust=-.1, size=6) +
        # Flip 90 degrees
        coord_flip() + 
        # Color Scales
        scale_color_brewer(gsub("PlantDay", "Planting\nDate", input$compare), palette="Set1") + 
        scale_fill_brewer(gsub("PlantDay", "Planting\nDate", input$compare), palette="Set1") + 
        # Remove Axis labels
        xlab("") + ylab("") + 
        # Add guide lines
        geom_vline(aes(xintercept=xintercept), data=guidelines) + 
        theme_bw() + 
        theme(plot.title=element_text(size=18), 
              axis.text = element_text(size = 16), 
              legend.title=element_text(size=16), 
              legend.text=element_text(size=14),
              panel.grid.major.x=element_line(color="grey40"), 
              panel.grid.minor.y=element_line(color="black")) +
        ggtitle("Development Timeline of Soybeans")
      
      # Frost date dotted lines: if Location is comparison, plot with colors, otherwise, black and white.
      if(input$compare=="Location") {
        plot <- plot + 
          geom_segment(aes(y=frost.date, yend=frost.date, x=y+.25, xend=Inf, 
                           color=factor(facet)), data=frost.date.df, linetype=2, show_guide=F)
      } else {
        plot <- plot + 
          geom_segment(aes(y=frost.date, yend=frost.date, x=y+.25, xend=Inf), 
                       data=frost.date.df, linetype=2, show_guide=F)
      }
    }
    # Print the plot!
    plot
  })
  
  # Function to draw a plot of yield by Maturity with options for plot type, displayed points (data and simulated values), and intervals.
  drawYieldByMGPlot <- reactive({
    # Are inputs present?
    if(length(input$location)>0 & length(input$planting)>0 & length(input$compare)>0){
      # Filter plotdata according to inputs
      plotdata <- filter(yield, 
                         Location%in%input$location &
                           PlantDay%in%input$planting)
      plotdata$Location <- factor(plotdata$Location, levels=input$location, ordered=T)
      # Choose facet/color variable with care - if X = comparison variable, show blank plot. 
      if(input$compare!="MG"){
        plotdata$facet <- plotdata[,input$compare]
      } else {
        plotdata$facet <- NA
      }
      
      # Include failed trials?
      if(!input$failed){
        plotdata <- filter(plotdata, Comment!="failure")
      }
      
      # Any non-zero yield data? If not, draw a plot saying "No yield". Otherwise, continue. 
      if(sum(plotdata$Yield!=0)==0){
        plot <- qplot(x=0, y=0, label="No yield under these parameters", geom="text") + 
          theme_bw() + 
          theme(plot.title = element_text(size = 18), 
                legend.title = element_text(size = 16), 
                legend.text = element_text(size = 14), 
                axis.text = element_blank(), 
                axis.title = element_blank(),
                axis.ticks = element_blank(),
                legend.position="bottom",
                legend.direction="horizontal") + 
          ggtitle(paste0("Relative Yield by Maturity Group")) + 
          xlab(NULL) + ylab(NULL)
      } else {
      # Plot of yield data
        plotdata <- plotdata %>% group_by(facet) %>% mutate(nyield=100*Yield/max(Yield)) %>% as.data.frame
        plotdata$jitterMG <- jitter(plotdata$MG, amount=.2)
        
      # Fit splines for each selected case 
      # Splines are used instead of loess because it's easier to get SE/prediction intervals out. 
        spline.data <- plotdata %>% group_by(facet) %>% do({
          set.seed(9852996)
          bx3 <- cbind(I=1, ns(.$jitterMG, df=3)) 
          cubicspline3 <- lm(data=., nyield~bx3-1)
          tmp <- data.frame(MG=.$MG, jitterMG=.$jitterMG)
          tmp <- cbind(tmp, suppressWarnings(predict(cubicspline3, se.fit=T, interval="prediction", level=.95)))
          tmp
        })
        
        # Find maximum value for each spline
        spline.max <- spline.data %>% group_by(facet) %>% do({
          .[which.max(.$fit.fit),]
        })
        
        # "Jitter" non-unique maximum values so dotted line is visible for each factor variable (e.g. Location)
        if(nrow(spline.max)>1 & length(unique(spline.max$MG))<nrow(spline.max)){
          spline.max$MG <- spline.max$MG + seq(-.05, .05, length.out = nrow(spline.max))
        }    
        
        # Plot points (if selected)
        if(input$points){
          plot <- ggplot() + 
            geom_point(data=plotdata, aes(x=jitterMG, y=nyield), alpha=.25) 
        } else {
          plot <- ggplot()
        }
        
        # Plot new data (2014 trials) if selected
        if(input$newdata2){
          newdata <- filter(plotdata, Year==2014)
          if(nrow(newdata)>0){
            if(sum(is.na(plotdata$facet))>0){
              plot <- plot + 
                geom_jitter(data=newdata, aes(x=jitterMG, y=nyield), size=3, alpha=.75) 
            } else {
              plot <- plot + 
                geom_jitter(data=newdata, aes(x=jitterMG, y=nyield, color=factor(facet)), size=3, alpha=.75) 
            }
          }
        }
        
        if(input$plottype2=="2"){
          # Plot lines
          if(sum(is.na(plotdata$facet))>0){
            # If no facets (because MG is selected for comparison) then use a plain plot
            plot <- plot + 
              geom_line(data=spline.data, aes(x=jitterMG, y=fit.fit), size=2)
            if(input$ci){
              plot <- plot  + 
                geom_line(data=spline.data, aes(x=jitterMG, y=fit.lwr), 
                          linetype=2) + 
                geom_line(data=spline.data, aes(x=jitterMG, y=fit.upr), 
                          linetype=2) 
            }
          } else {
            # Color and such
            plot <- plot + 
              geom_line(data=spline.data, aes(x=jitterMG, y=fit.fit, colour=factor(facet)), size=2, alpha=1/sqrt(nrow(spline.max))) +
              scale_colour_brewer(gsub("PlantDay", "Planting\nDate", input$compare),palette="Set1") + 
              geom_segment(data=spline.max, aes(x=MG, y=fit.fit, xend=MG, yend=0, colour=factor(facet), ymax=fit.fit), linetype=4, size=2)
            if(input$ci){
              plot <- plot + 
                geom_line(data=spline.data, 
                          aes(x=jitterMG, y=fit.lwr, colour=factor(facet)),
                          linetype=2) + 
                geom_line(data=spline.data, 
                          aes(x=jitterMG, y=fit.upr, colour=factor(facet)),
                          linetype=2)  
            }
          }
        } else {
          # Plot boxplots
          if(sum(is.na(plotdata$facet))>0){
            plot <- plot + 
              geom_boxplot(data=plotdata, aes(x=MG, y=nyield, group=round_any(MG*2, 1)/2), fill=NA)
          } else {
            plot <- plot + 
              geom_boxplot(data=plotdata, aes(x=MG, y=nyield, colour=factor(facet), 
                                              group=interaction(factor(facet), round_any(MG*2, 1)/2)), 
                           fill=NA, position=position_dodge()) + 
              scale_colour_brewer(gsub("PlantDay", "Planting\nDate", input$compare),palette="Set1")
            if(length(unique(plotdata$facet))>1)
              plot <- plot + geom_vline(aes(xintercept=-1:5+.5), colour="grey30")
          }
        }
        
        # Other plot decorations, like labels
        plot <- plot + 
          scale_y_continuous(breaks=c(0, 25, 50, 75, 100), name="Relative Yield (%)", limits=c(min(c(0,spline.data$fit.fit)), 110)) + 
          scale_x_continuous(breaks=0:5, labels=0:5, name="Maturity Group") + 
          theme_bw() + 
          theme(plot.title = element_text(size = 18), 
                legend.title = element_text(size = 16), 
                legend.text = element_text(size = 14), 
                axis.text = element_text(size = 14), 
                axis.title = element_text(size = 16), 
                legend.position="bottom",
                legend.direction="horizontal") + 
          ggtitle(paste0("Relative Yield by Maturity Group"))
      }
    } else {
      # "I have no input" plot
      plot <- qplot(x=0, y=0, label="Waiting for input", geom="text") + 
        theme_bw() + 
        theme(plot.title = element_text(size = 18), 
              legend.title = element_text(size = 16), 
              legend.text = element_text(size = 14), 
              axis.text = element_blank(), 
              axis.title = element_blank(),
              axis.ticks = element_blank(),
              legend.position="bottom",
              legend.direction="horizontal") + 
        ggtitle(paste0("Relative Yield by Maturity Group")) + 
        xlab(NULL) + ylab(NULL)
    }
    # Print the plot!
    plot
  })
  
  drawYieldByPlantingPlot <- reactive({
    # Are inputs present?
    if(length(input$location)>0 & length(input$maturity)>0 & length(input$compare)>0){
      # Filter plotdata according to inputs
      plotdata <- filter(yield, 
                         Location%in%input$location &
                           MG%in%input$maturity)
      plotdata$Location <- factor(plotdata$Location, levels=input$location, ordered=T)
      # Choose facet/color variable with care - if X = comparison variable, show blank plot. 
      if(input$compare!="PlantDay"){
        plotdata$facet <- plotdata[,input$compare]
      } else {
        plotdata$facet <- NA
      }
      
      # Include failed trials?
      if(!input$failed){
        plotdata <- filter(plotdata, Comment!="failure")
      }
      
      # Any non-zero yield data? If not, draw a plot saying "No yield". Otherwise, continue. 
      if(sum(plotdata$Yield!=0)==0){
        plot <- qplot(x=0, y=0, label="No yield under these parameters", geom="text") + 
          theme_bw() + 
          theme(plot.title = element_text(size = 18), 
                legend.title = element_text(size = 16), 
                legend.text = element_text(size = 14), 
                axis.text = element_blank(), 
                axis.title = element_blank(),
                axis.ticks = element_blank(),
                legend.position="bottom",
                legend.direction="horizontal") + 
          ggtitle(paste0("Relative Yield by Maturity Group")) + 
          xlab(NULL) + ylab(NULL)
      } else {
        # Plot of yield data
        plotdata$nyield <- 100*plotdata$Yield/max(plotdata$Yield, na.rm=TRUE)
        plotdata$jitterDate <- yday(plotdata$Planting2)
        
        # Fit splines for each selected case 
        # Splines are used instead of loess because it's easier to get SE/prediction intervals out. 
        spline.data <- plotdata %>% group_by(facet) %>% do({
          set.seed(9852996)
          bx5 <- cbind(I=1, ns(.$jitterDate, df=5)) 
          cubicspline5 <- lm(data=., nyield~bx5-1)
          tmp <- data.frame(jitterDate=.$jitterDate)
          tmp <- cbind(tmp, suppressWarnings(predict(cubicspline5, se.fit=T, interval="prediction", level=.95)))
          tmp
        })
        
        # Find maximum value for each spline
        spline.max <- spline.data %>% group_by(facet) %>% do({
          .[which.max(.$fit.fit),]
        })
        
        # Plot points (if selected)
        if(input$points){
          plot <- ggplot() + 
            geom_jitter(data=plotdata, aes(x=jitterDate, y=nyield), alpha=.25) 
        } else {
          plot <- ggplot()
        }
        
        # Plot new data (2014 trials) if selected
        if(input$newdata2){
          newdata <- filter(plotdata, Year==2014)
          if(nrow(newdata)>0){
            if(sum(is.na(plotdata$facet))>0){
              plot <- plot + 
                geom_jitter(data=newdata, aes(x=jitterDate, y=nyield), size=3, alpha=.75)
            } else {
              plot <- plot + 
                geom_jitter(data=newdata, aes(x=jitterDate, y=nyield, color=factor(facet)), size=3, alpha=.75) 
              
            }
          }
        }
        
        # If no facets (because Planting Date is selected for comparison) use a plain plot
        if(sum(is.na(plotdata$facet))>0){
          plot <- plot + 
            geom_line(data=spline.data, aes(x=jitterDate, y=fit.fit), size=2) + 
            geom_segment(data=spline.max, aes(x=jitterDate, y=fit.fit, xend=jitterDate, yend=0), size=2, linetype=4)
          if(input$ci){
            plot <- plot + 
              geom_line(data=spline.data, aes(x=jitterDate, y=fit.lwr), 
                        linetype=2) + 
              geom_line(data=spline.data, aes(x=jitterDate, y=fit.upr), 
                        linetype=2)
          }
        } else {
          # Color and such
          plot <- plot + 
            geom_line(data=spline.data, aes(x=jitterDate, y=fit.fit, colour=factor(facet)), size=2, alpha=1/sqrt(nrow(spline.max))) + 
            scale_colour_brewer(gsub("PlantDay", "Planting\nDate", input$compare),palette="Set1") + 
            geom_segment(data=spline.max, aes(x=jitterDate, y=fit.fit, xend=jitterDate, yend=0, colour=factor(facet)), linetype=4, size=2)
          if(input$ci){
            plot <- plot + 
              geom_line(data=spline.data, 
                        aes(x=jitterDate, y=fit.lwr, colour=factor(facet)),
                        linetype=2) + 
              geom_line(data=spline.data, 
                        aes(x=jitterDate, y=fit.upr, colour=factor(facet)),
                        linetype=2)
          }
        }
        
        # Other plot decorations, like labels
        plot <-  plot + 
          scale_y_continuous(breaks=c(0, 25, 50, 75, 100), name="Relative Yield (%)", limits=c(min(c(0,spline.data$fit.fit)), 110)) + 
          scale_x_continuous("Planting Date", breaks=c(92, 122, 153, 183, 214, 245), 
                             labels=c("Apr", "May", "Jun", "Jul", "Aug", "Sept")) + 
          theme_bw() + 
          theme(plot.title = element_text(size = 18), 
                legend.title = element_text(size = 16), 
                legend.text = element_text(size = 14), 
                axis.text = element_text(size = 14), 
                axis.title = element_text(size = 16),
                axis.title.x = element_blank(),
                legend.position="bottom",
                legend.direction="horizontal") + 
          ggtitle(paste0("Relative Yield by Planting Date"))
      }
    } else {
      # "I have no input" plot
      plot <- qplot(x=0, y=0, label="Waiting for input", geom="text") + 
        theme_bw() + 
        theme(plot.title = element_text(size = 18), 
              legend.title = element_text(size = 16), 
              legend.text = element_text(size = 14), 
              axis.text = element_blank(), 
              axis.title = element_blank(),
              axis.ticks = element_blank(),
              legend.position="bottom",
              legend.direction="horizontal") + 
        ggtitle(paste0("Relative Yield by Planting Date")) + 
        xlab(NULL) + ylab(NULL)
    }
    # Print the plot!
    plot
  })
  
  # Separate functions to draw the plots
  # This allows us to separate the drawing of the plot from its rendering. 
  
  # Plot of development progress
  output$DevelopmentPlot <- renderPlot({
    print(drawDevelopmentPlot())
  })

  # Plot of Yield by MG
  output$YieldByMGPlot <- renderPlot({
    print(drawYieldByMGPlot())
  })
  
  # Plot of Yield by Planting Date
  output$YieldByPlantingPlot <- renderPlot({
    print(drawYieldByPlantingPlot())
  })
})