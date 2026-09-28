import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/community_post.dart';

class CommunityPostsList extends StatelessWidget {
  final List<CommunityPost> posts;
  final VoidCallback? onAddTap;
  final Function(CommunityPost post)? onPostTap;

  const CommunityPostsList({
    super.key,
    required this.posts,
    this.onAddTap,
    this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resultados de la Comunidad',
                style: GoogleFonts.inter(
                  color: const Color(0xFF171717),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (onAddTap != null)
                TextButton.icon(
                  onPressed: onAddTap,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18, color: Colors.black),
                  label: Text(
                    'Compartir',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (posts.isEmpty)
          Container(
            height: 100,
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Text(
              'Sé el primero en compartir con la comunidad',
              style: GoogleFonts.inter(
                color: const Color(0xFF737373),
                fontSize: 13,
              ),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return GestureDetector(
                  onTap: () => onPostTap?.call(post),
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          post.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF5F5F5),
                            child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.75),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.visibility_outlined, color: Colors.white70, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${post.views}',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.favorite, color: Colors.white70, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${post.likes}',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
