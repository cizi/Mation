using Toybox.Math;

class UiCalc {


  // Calculate the coordinates for indicators numbers (hours) on the edge of the dial
  function calculateSmallDialLines(halfWidth) {
    var linesCoords = {};
    var angleDeg = 0;
    var pointX =  0;
    var pointY = 0;
    for(var angle = 0; angle < 360; angle+=15) {
      if ((angle != 0) && (angle != 90) && (angle != 180) && (angle != 270)) {
        angleDeg = (angle * Math.PI) / 180;
        pointX = ((halfWidth * Math.cos(angleDeg)) + halfWidth);
        pointY = ((halfWidth * Math.sin(angleDeg)) + halfWidth);
        linesCoords.put(angle, [pointX, pointY]);
      }
    }

    return linesCoords;
  }
  
  
  function calculateScaleMeter(from, to, halfWidth, startCircle, smallEnd, bigEnd, masterEnd) {
        var linesCoords = {};
        var angleDeg = 0;
        var pointX1 =  0;
        var pointY1 = 0;
        var pointX2 = 0;
        var pointY2 = 0;
        
        for(var angle = from; angle < to; angle+=3) {
            angleDeg = (angle * Math.PI) / 180;
            pointX1 = ((startCircle * Math.cos(angleDeg)) + halfWidth);
            pointY1 = ((startCircle * Math.sin(angleDeg)) + halfWidth);
            
            pointX2 = ((smallEnd * Math.cos(angleDeg)) + halfWidth);
            pointY2 = ((smallEnd * Math.sin(angleDeg)) + halfWidth);
            
            linesCoords.put(angle, [pointX1, pointY1, pointX2, pointY2]);
        }

        for(var angle = from; angle < to; angle+=9) {
            angleDeg = (angle * Math.PI) / 180;
            pointX1 = ((startCircle * Math.cos(angleDeg)) + halfWidth);
            pointY1 = ((startCircle * Math.sin(angleDeg)) + halfWidth);
            
            pointX2 = ((bigEnd * Math.cos(angleDeg)) + halfWidth);
            pointY2 = ((bigEnd * Math.sin(angleDeg)) + halfWidth);
            
            linesCoords.put(angle, [pointX1, pointY1, pointX2, pointY2]);
        }
        
        angleDeg = (from * Math.PI) / 180;
        pointX1 = ((startCircle * Math.cos(angleDeg)) + halfWidth);
        pointY1 = ((startCircle * Math.sin(angleDeg)) + halfWidth);       
        pointX2 = ((masterEnd * Math.cos(angleDeg)) + halfWidth);
        pointY2 = ((masterEnd * Math.sin(angleDeg)) + halfWidth);  
        linesCoords.put(from, [pointX1, pointY1, pointX2, pointY2]);
        
        angleDeg = ((from + 45) * Math.PI) / 180;
        pointX1 = ((startCircle * Math.cos(angleDeg)) + halfWidth);
        pointY1 = ((startCircle * Math.sin(angleDeg)) + halfWidth);       
        pointX2 = ((masterEnd * Math.cos(angleDeg)) + halfWidth);
        pointY2 = ((masterEnd * Math.sin(angleDeg)) + halfWidth);  
        linesCoords.put((from + 45), [pointX1, pointY1, pointX2, pointY2]);
        
        angleDeg = ((from + 90) * Math.PI) / 180;
        pointX1 = ((startCircle * Math.cos(angleDeg)) + halfWidth);
        pointY1 = ((startCircle * Math.sin(angleDeg)) + halfWidth);       
        pointX2 = ((masterEnd * Math.cos(angleDeg)) + halfWidth);
        pointY2 = ((masterEnd * Math.sin(angleDeg)) + halfWidth);  
        linesCoords.put((from + 90), [pointX1, pointY1, pointX2, pointY2]);
    
        return linesCoords;
    }
}
