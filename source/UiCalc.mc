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

}
