library(shiny)
library(leaflet)
library(rgdal) #for reading/writing geo files
library(rgeos) #for simplification
library(sp)


# set the working directory
#setwd("<SET TO YOUR WORKING DIRECTORY>")


if (!file.exists("simplified.RData")) {
  cat("Building simplified data, this may take a while...\n\n")
  local({
    # load country and state data; convert NA's to "Unknown"
    countries <- readOGR(dsn = "ne_10m_admin_0_countries/ne_10m_admin_0_countries.shp",
                         layer = "ne_10m_admin_0_countries")
    states <- readOGR(dsn = "ne_10m_admin_1_states_provinces/ne_10m_admin_1_states_provinces.shp",
                      layer = "ne_10m_admin_1_states_provinces")
    
    # convert NA's to "Unknown" in columns we are using
    countries@data$NAME_LONG <- factor(countries@data$NAME_LONG, levels = c(levels(countries@data$NAME_LONG), "Unknown"))
    countries@data$NAME_LONG[is.na(countries@data$NAME_LONG)] <- "Unknown"
    
    states@data$geonunit <- factor(states@data$geonunit, levels = c(levels(states@data$geonunit), "Unknown"))
    states@data$geonunit[is.na(states@data$geonunit)] <- "Unknown"
    states@data$name <- factor(states@data$name, levels = c(levels(states@data$name), "Unknown"))
    states@data$name[is.na(states@data$name)] <- "Unknown"
    
    # simplify shapefile for improved performance
    tol <- 0.0001
    
    countriesSimplified <- gSimplify(countries, tol, topologyPreserve = TRUE)
    countries <- SpatialPolygonsDataFrame(countriesSimplified, data = countries@data)
    
    statesSimplified <- gSimplify(states, tol, topologyPreserve = TRUE)
    states <- SpatialPolygonsDataFrame(statesSimplified, data = states@data)
    
    save("countries", "states", file = "simplified.RData")
  })
}


load("simplified.RData")


# Create the country map at app initialization
paletteCountry <- colorQuantile("YlGnBu", countries$POP_EST, n = 10)
info <- paste0("<h4><b>Hover over a country to view information.</h4></b>")




############################################################################
# Define server logic
shinyServer(function(input, output, session) {
  
  # initialize country to NULL
  selectedCountry <- NULL
  
  # Turn selectedCountry into reactive value; any change to selectedCountry will
  # notify reactive dependents
  makeReactiveBinding("selectedCountry")
  
  ### initialize map at country level
  output$mymap <- renderLeaflet({
    leaflet(countries) %>%
      addTiles(group = "OpenStreetMap") %>%
      addProviderTiles(provider = "Stamen.TonerLite", group = "Stamen Toner Lite") %>%
      addPolygons(layerId = ~NAME_LONG,
                  stroke = FALSE, fillOpacity = 0.5, smoothFactor = 0.5,
                  color = ~paletteCountry(POP_EST),
                  group = "countries"
      ) %>%
      addLayersControl(baseGroups = c("Stamen Toner Lite", "OpenStreetMap"),
                       position = "bottomleft",
                       options = layersControlOptions(collapsed = FALSE))
  })
  
  # Returns the set of
  currentStates <- reactive({
    
    if (is.null(selectedCountry)){
      return(NULL)
    } 
    
    if(selectedCountry == "United States"){
      states[states$geonunit == "United States of America",]
    } else if(selectedCountry == "Baikonur Cosmodrome"){
      states[states$geonunit == "Baykonur Cosmodrome",]
    } else if(selectedCountry == "Russian Federation"){
      states[states$geonunit == "Russia",]
    } else{
      states[grepl(selectedCountry, factor(states$geonunit), fixed = TRUE),]
    }
    
  })
  
  observe({
    # Immediately clear whatever is on the map
    leafletProxy("mymap", deferUntilFlush = FALSE) %>%
      hideGroup("countries") %>%
      clearGroup("states") %>%
      removeControl("infoControl") %>%
      removeControl("legend")
    
    if (is.null(selectedCountry)) {
      # Show all countries
      leafletProxy("mymap", data = countries) %>%
        setView(lng = 0, lat = 0, zoom = 2) %>%
        showGroup("countries") %>%
        addLegend(layerId = "legend", title = c("Population"), position = "bottomright", pal = paletteCountry, values = ~POP_EST) %>%
        addControl(layerId = "infoControl", html = info, position = "topright", className = "info")
    
    } else if (selectedCountry == "United States"){
      # Show states in selected country
      paletteState <- colorFactor(palette = "YlGnBu", domain = sort(currentStates()$name_len))
      info <- paste0("<h4><b> over a state to view information.</h4></b>")
      
      leafletProxy(mapId = "mymap", data = currentStates()) %>%
        addPolygons(layerId = ~name,
                    stroke = FALSE,
                    fillOpacity = 0.5,
                    smoothFactor = 0,
                    color = ~paletteState(name_len),
                    group = "states"
        ) %>%
        addLegend(layerId = "legend", title = c("Name Length"), position = "bottomright", pal = paletteState, values = ~sort(name_len)) %>%
        addControl(layerId = "infoControl", html = info, position = "topright", className = "info") %>%
        setView(lat = 51.0411425, lng = -95.8022806, zoom = 3)
      
    } else{
      
      paletteState <- colorFactor(palette = "YlGnBu", domain = sort(currentStates()$name_len))
      info <- paste0("<h4><b>Hover over a state to view information.</h4></b>")
      
      bounds <- bbox(currentStates())
                
      leafletProxy(mapId = "mymap", data = currentStates()) %>%
        addPolygons(layerId = ~name,
                    stroke = FALSE,
                    fillOpacity = 0.5,
                    smoothFactor = 0,
                    color = ~paletteState(name_len),
                    group = "states"
        ) %>%
        addLegend(layerId = "legend", title = c("Name Length"), position = "bottomright", pal = paletteState, values = ~sort(name_len)) %>%
        addControl(layerId = "infoControl", html = info, position = "topright", className = "info") %>%
        fitBounds(bounds[1], bounds[2], bounds[3], bounds[4])
    }
  })
  
  # adjust info control based on hover
  observeEvent(input$mymap_shape_mouseover, {
    
    # if the map is at the country level, then display country information
    if (is.null(selectedCountry)) {
      
      country <- countries[countries$NAME_LONG == input$mymap_shape_mouseover$id,]
      infoCountry <- paste0("<h4><b>Country: </b>", country$NAME_LONG, "<br><b>Population: </b>", format(x = country$POP_EST, format = "d", big.mark = ","), "<h4>")
      
      leafletProxy("mymap") %>%
        removeControl(layerId = "infoControl") %>%
        addControl(layerId = "infoControl", html = infoCountry, position = "topright", className = "info")
    
    # else display state information  
    } else {
      state <- currentStates()[currentStates()$name == input$mymap_shape_mouseover$id,]
      infoState <- paste0("<h4><b>State: </b>", state$name, "<br><b>Name Length: </b>", state$name_len, "<h4>")
      
      leafletProxy("mymap") %>%
        removeControl(layerId = "infoControl") %>%
        addControl(layerId = "infoControl", html = infoState, position = "topright", className = "info")
    }
  })
  
  
  observeEvent(input$mymap_shape_click, {
    if (is.null(selectedCountry)) {
      selectedCountry <<- input$mymap_shape_click$id
    }
  })
  
  # if the user clicks anywhere outside the polygon or on the action button, reset to first country map
  observeEvent(input$countryAction, {
    selectedCountry <<- NULL
  })
  
  observeEvent(input$mymap_click, {
    selectedCountry <<- NULL
  })
  
  
})