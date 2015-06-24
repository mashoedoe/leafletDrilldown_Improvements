library(shiny)
library(leaflet)
library(rgdal) #for reading/writing geo files
library(rgeos) #for simplification
library(sp)


# Define UI for application that draws a histogram
shinyUI(bootstrapPage(
  tags$style(type = "text/css", "html, body {width:100%;height:100%}"),
  #tags$head(includeScript("zoombounds.js")),
  
  leafletOutput("mymap", width = "100%", height = "100%"), 
  
  absolutePanel(bottom = 10, right = 180, left = 180, fixed = TRUE, draggable = TRUE, 
    #actionButton("countryAction", "Reset to Country Map"),
    helpText(HTML("<h2>Reset to the country level map by clicking anywhere outside the polygons.</h2>")),
  #   actionButton("stateAction", "State Layer"),
    p(),
  #   leafletOutput("mymap", height = 600),
  
#     textOutput("bounds"),
#     textOutput("zoom"),
#     textOutput("mouseover"),
  
#     textOutput("indTest1"),
#     textOutput("indTest2"),
#     textOutput("indTest3"),
#     textOutput("indTest4"),
  #   textOutput("boolean"),
  #   textOutput("env"),
  #   textOutput("message"),
     
    
    p()
  
  )
  
))